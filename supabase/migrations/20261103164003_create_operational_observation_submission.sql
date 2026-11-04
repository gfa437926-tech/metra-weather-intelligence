create table if not exists public.metra_observations (
  id uuid primary key default gen_random_uuid(),
  station_id uuid not null references public.station_catalogue(id),
  created_by uuid not null references auth.users(id),
  observation_type text not null check (observation_type in ('daily','hourly','phenomenon')),
  observed_at timestamptz not null,
  payload jsonb not null check (jsonb_typeof(payload) = 'object' and pg_column_size(payload) <= 65536),
  status text not null check (status in ('draft','submitted','returned','approved')),
  initial_status text not null check (initial_status in ('draft','submitted')),
  idempotency_key text not null check (length(btrim(idempotency_key)) between 1 and 128),
  submitted_at timestamptz,
  reviewed_by uuid references auth.users(id),
  reviewed_at timestamptz,
  review_note text check (review_note is null or length(review_note) <= 2000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (station_id, created_by, idempotency_key)
);
comment on table public.metra_observations is 'Operational user-entered METRA observations. Separate from immutable legacy import envelopes in metra_observation_records.';
create index if not exists metra_observations_station_status_observed_idx on public.metra_observations (station_id, status, observed_at desc);
create index if not exists metra_observations_creator_created_idx on public.metra_observations (created_by, created_at desc);

create table if not exists public.metra_observation_audit_events (
  id bigint generated always as identity primary key,
  observation_id uuid not null references public.metra_observations(id),
  station_id uuid not null references public.station_catalogue(id),
  actor_user_id uuid not null references auth.users(id),
  event_type text not null check (event_type in ('created_draft','submitted','returned','approved','resubmitted')),
  from_status text check (from_status is null or from_status in ('draft','submitted','returned','approved')),
  to_status text not null check (to_status in ('draft','submitted','returned','approved')),
  note text check (note is null or length(note) <= 2000),
  occurred_at timestamptz not null default now()
);
create index if not exists metra_observation_audit_observation_time_idx on public.metra_observation_audit_events (observation_id, occurred_at desc);

alter table public.metra_observations enable row level security;
alter table public.metra_observations force row level security;
alter table public.metra_observation_audit_events enable row level security;
alter table public.metra_observation_audit_events force row level security;
revoke all on public.metra_observations from public, anon, authenticated, metra_api_runtime;
revoke all on public.metra_observation_audit_events from public, anon, authenticated, metra_api_runtime;
grant select, insert on public.metra_observations to service_role;
grant select, insert on public.metra_observation_audit_events to service_role;

create or replace function public.reject_metra_observation_audit_mutation()
returns trigger language plpgsql set search_path = pg_catalog, public as $$
begin
  raise exception 'METRA observation audit events are append-only' using errcode = '55000';
end;
$$;
revoke all on function public.reject_metra_observation_audit_mutation() from public, anon, authenticated, service_role;
create trigger metra_observation_audit_immutable
before update or delete on public.metra_observation_audit_events
for each row execute function public.reject_metra_observation_audit_mutation();

create or replace function public.metra_submit_observation(
  p_user_id uuid, p_station_id uuid, p_idempotency_key text,
  p_observation_type text, p_observed_at timestamptz, p_payload jsonb,
  p_submit boolean default false
)
returns jsonb language plpgsql security definer
set search_path = pg_catalog, public as $$
declare
  v_observation public.metra_observations%rowtype;
  v_initial_status text;
begin
  if p_user_id is null or p_station_id is null then
    raise exception 'user_id_and_station_id_required' using errcode = '22023';
  end if;
  if p_idempotency_key is null or length(btrim(p_idempotency_key)) not between 1 and 128 then
    raise exception 'invalid_idempotency_key' using errcode = '22023';
  end if;
  if p_observation_type not in ('daily','hourly','phenomenon') then
    raise exception 'invalid_observation_type' using errcode = '22023';
  end if;
  if p_observed_at is null or p_payload is null or jsonb_typeof(p_payload) <> 'object'
     or pg_column_size(p_payload) > 65536 then
    raise exception 'invalid_observation_payload' using errcode = '22023';
  end if;
  if not public.metra_user_has_station_permission(p_user_id, p_station_id, 'observation.create') then
    raise exception 'station_observation_create_forbidden' using errcode = '42501';
  end if;
  if coalesce(p_submit, false) and
     not public.metra_user_has_station_permission(p_user_id, p_station_id, 'observation.submit') then
    raise exception 'station_observation_submit_forbidden' using errcode = '42501';
  end if;
  v_initial_status := case when coalesce(p_submit, false) then 'submitted' else 'draft' end;

  insert into public.metra_observations (
    station_id, created_by, observation_type, observed_at, payload,
    status, initial_status, idempotency_key, submitted_at
  ) values (
    p_station_id, p_user_id, p_observation_type, p_observed_at, p_payload,
    v_initial_status, v_initial_status, p_idempotency_key,
    case when v_initial_status = 'submitted' then now() else null end
  )
  on conflict (station_id, created_by, idempotency_key) do nothing
  returning * into v_observation;

  if v_observation.id is null then
    select * into v_observation from public.metra_observations
     where station_id = p_station_id and created_by = p_user_id
       and idempotency_key = p_idempotency_key for update;
    if v_observation.observation_type <> p_observation_type
       or v_observation.observed_at <> p_observed_at
       or v_observation.payload <> p_payload
       or v_observation.initial_status <> v_initial_status then
      raise exception 'idempotency_key_reused_with_different_request' using errcode = '23505';
    end if;
    return jsonb_build_object('id', v_observation.id, 'status', v_observation.status, 'replayed', true);
  end if;

  insert into public.metra_observation_audit_events (
    observation_id, station_id, actor_user_id, event_type, from_status, to_status
  ) values (
    v_observation.id, p_station_id, p_user_id,
    case when v_initial_status = 'submitted' then 'submitted' else 'created_draft' end,
    null, v_initial_status
  );
  return jsonb_build_object('id', v_observation.id, 'status', v_observation.status, 'replayed', false);
end;
$$;

revoke all on function public.metra_submit_observation(uuid,uuid,text,text,timestamptz,jsonb,boolean)
  from public, anon, authenticated, metra_api_runtime;
grant execute on function public.metra_submit_observation(uuid,uuid,text,text,timestamptz,jsonb,boolean)
  to service_role;
