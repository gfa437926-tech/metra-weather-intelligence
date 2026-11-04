-- Initial registration workflow persistence for the NEW METRA project.
alter table public.metra_user_profiles
  add column phone text,
  add constraint metra_user_profiles_phone_check
    check (phone is null or (length(trim(phone)) between 1 and 40 and phone = trim(phone)));

create table public.metra_role_catalogue (
  role_code text primary key,
  name_ar text not null,
  name_en text not null,
  description_ar text,
  description_en text,
  is_requestable boolean not null default false,
  is_active boolean not null default true,
  display_order integer not null default 100,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint metra_role_catalogue_code_check
    check (role_code = lower(role_code) and role_code ~ '^[a-z0-9]+([._-][a-z0-9]+)*$' and length(role_code) <= 128),
  constraint metra_role_catalogue_name_ar_check check (length(trim(name_ar)) between 1 and 160),
  constraint metra_role_catalogue_name_en_check check (length(trim(name_en)) between 1 and 160),
  constraint metra_role_catalogue_display_order_check check (display_order between 0 and 10000)
);
create trigger metra_role_catalogue_set_updated_at
  before update on public.metra_role_catalogue
  for each row execute function private.set_updated_at();

create table public.registration_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete restrict,
  requested_station_id uuid not null,
  requested_authority_id uuid not null,
  requested_role_code text not null references public.metra_role_catalogue(role_code) on update restrict on delete restrict,
  status text not null default 'pending_station_approval',
  phone_snapshot text,
  terms_version text not null,
  terms_accepted_at timestamptz not null,
  submitted_at timestamptz not null default now(),
  idempotency_key text not null,
  payload_hash bytea not null,
  reviewed_by uuid references auth.users(id) on delete restrict,
  reviewed_at timestamptz,
  review_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint registration_requests_station_authority_fk
    foreign key (requested_station_id, requested_authority_id)
    references public.station_catalogue(id, owner_authority_id) on delete restrict,
  constraint registration_requests_status_check
    check (status in ('pending_station_approval','pending_system_approval','active','rejected')),
  constraint registration_requests_terms_version_check
    check (length(trim(terms_version)) between 1 and 64 and terms_version = trim(terms_version)),
  constraint registration_requests_idempotency_key_check
    check (length(trim(idempotency_key)) between 1 and 128 and idempotency_key = trim(idempotency_key)),
  constraint registration_requests_payload_hash_check check (octet_length(payload_hash) = 32),
  constraint registration_requests_phone_check
    check (phone_snapshot is null or (length(trim(phone_snapshot)) between 1 and 40 and phone_snapshot = trim(phone_snapshot))),
  constraint registration_requests_review_consistency check ((reviewed_by is null) = (reviewed_at is null)),
  constraint registration_requests_review_note_check check (review_note is null or length(review_note) <= 2000)
);
create unique index registration_requests_user_idempotency_uq
  on public.registration_requests(user_id, idempotency_key);
create unique index registration_requests_one_open_per_user_uq
  on public.registration_requests(user_id)
  where status in ('pending_station_approval','pending_system_approval');
create index registration_requests_queue_station_idx
  on public.registration_requests(status, requested_station_id, submitted_at desc, id desc);
create index registration_requests_queue_system_idx
  on public.registration_requests(status, submitted_at desc, id desc);
create index registration_requests_user_history_idx
  on public.registration_requests(user_id, submitted_at desc, id desc);
create trigger registration_requests_set_updated_at
  before update on public.registration_requests
  for each row execute function private.set_updated_at();

create table public.registration_audit_events (
  id bigint generated always as identity primary key,
  request_id uuid not null references public.registration_requests(id) on delete restrict,
  user_id uuid not null references auth.users(id) on delete restrict,
  actor_user_id uuid not null references auth.users(id) on delete restrict,
  event_type text not null,
  terms_version text not null,
  correlation_id text,
  occurred_at timestamptz not null default now(),
  constraint registration_audit_event_type_check
    check (event_type in ('registration_submitted','station_approved','station_rejected','system_approved','system_rejected')),
  constraint registration_audit_terms_version_check check (length(trim(terms_version)) between 1 and 64),
  constraint registration_audit_correlation_id_check check (correlation_id is null or length(correlation_id) <= 128)
);
create index registration_audit_request_history_idx
  on public.registration_audit_events(request_id, occurred_at desc, id desc);
create index registration_audit_user_history_idx
  on public.registration_audit_events(user_id, occurred_at desc, id desc);

create or replace function private.reject_registration_audit_mutation()
returns trigger language plpgsql set search_path = pg_catalog
as $$
begin
  raise exception 'registration audit events are append-only' using errcode = '55000';
end;
$$;
revoke all on function private.reject_registration_audit_mutation() from public, anon, authenticated;
create trigger registration_audit_events_append_only
  before update or delete on public.registration_audit_events
  for each row execute function private.reject_registration_audit_mutation();

create or replace function private.validate_registration_request_catalogue()
returns trigger language plpgsql set search_path = pg_catalog, public
as $$
declare station_ok boolean; role_ok boolean;
begin
  select exists (
    select 1 from public.station_catalogue s
    join public.meteorological_authorities a on a.id = s.owner_authority_id
    where s.id = new.requested_station_id
      and s.owner_authority_id = new.requested_authority_id
      and s.approval_status = 'approved'
      and s.operational_status = 'active'
      and s.is_demo = false
      and a.is_active = true
    for share of s, a
  ) into station_ok;
  select exists (
    select 1 from public.metra_role_catalogue r
    where r.role_code = new.requested_role_code
      and r.is_active = true and r.is_requestable = true
    for share
  ) into role_ok;
  if not station_ok then
    raise exception 'requested station is not selectable'
      using errcode = '23514', constraint = 'registration_requests_station_selectable';
  end if;
  if not role_ok then
    raise exception 'requested role is not requestable'
      using errcode = '23514', constraint = 'registration_requests_role_requestable';
  end if;
  return new;
end;
$$;
revoke all on function private.validate_registration_request_catalogue() from public, anon, authenticated;
create trigger registration_requests_validate_catalogue
  before insert on public.registration_requests
  for each row execute function private.validate_registration_request_catalogue();

alter table public.metra_role_catalogue enable row level security;
alter table public.registration_requests enable row level security;
alter table public.registration_audit_events enable row level security;
create policy metra_role_catalogue_deny_clients on public.metra_role_catalogue
  for all to anon, authenticated using (false) with check (false);
create policy registration_requests_deny_clients on public.registration_requests
  for all to anon, authenticated using (false) with check (false);
create policy registration_audit_events_deny_clients on public.registration_audit_events
  for all to anon, authenticated using (false) with check (false);
revoke all on table public.metra_role_catalogue, public.registration_requests,
  public.registration_audit_events from anon, authenticated;
grant all on table public.metra_role_catalogue, public.registration_requests,
  public.registration_audit_events to service_role;
grant usage, select on sequence public.registration_audit_events_id_seq to service_role;

comment on table public.metra_role_catalogue is
  'Canonical METRA role codes; empty until domain owners approve role definitions.';
comment on table public.registration_requests is
  'Initial METRA registration workflow. Requested role/station are not effective grants until approval completes.';
comment on table public.registration_audit_events is
  'Append-only registration and approval audit events.';
