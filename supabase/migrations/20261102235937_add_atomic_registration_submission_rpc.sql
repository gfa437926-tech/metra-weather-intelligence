-- Atomic initial registration. The only callable application role is service_role;
-- the API must supply auth_user_id from the cryptographically validated JWT subject.
create or replace function public.submit_metra_registration(
  p_auth_user_id uuid,
  p_first_name text,
  p_father_name text,
  p_last_name text,
  p_phone text,
  p_role_code text,
  p_station_id uuid,
  p_terms_version text,
  p_submitted_at timestamptz,
  p_idempotency_key text
)
returns table (result_status text, account_id uuid, request_id uuid)
language plpgsql security definer
set search_path = pg_catalog, public, extensions
as $$
declare
  v_payload_hash bytea;
  v_existing public.registration_requests%rowtype;
  v_authority_id uuid;
  v_request_id uuid;
begin
  if p_auth_user_id is null or p_auth_user_id = '00000000-0000-0000-0000-000000000000'::uuid
     or p_first_name is null or length(trim(p_first_name)) not between 1 and 120
     or p_father_name is null or length(trim(p_father_name)) not between 1 and 120
     or p_last_name is null or length(trim(p_last_name)) not between 1 and 120
     or p_phone is not null and length(trim(p_phone)) not between 1 and 40
     or p_role_code is null or length(trim(p_role_code)) not between 1 and 128
     or p_station_id is null
     or p_terms_version is null or length(trim(p_terms_version)) not between 1 and 64
     or p_submitted_at is null
     or p_idempotency_key is null or length(trim(p_idempotency_key)) not between 1 and 128
  then
    raise exception 'invalid registration submission' using errcode = '22023';
  end if;

  v_payload_hash := extensions.digest(convert_to(jsonb_build_object(
    'version', 1, 'first_name', trim(p_first_name),
    'father_name', trim(p_father_name), 'last_name', trim(p_last_name),
    'phone', nullif(trim(p_phone), ''), 'role_code', trim(p_role_code),
    'station_id', p_station_id::text, 'terms_version', trim(p_terms_version)
  )::text, 'UTF8'), 'sha256');

  select r.* into v_existing from public.registration_requests r
   where r.user_id = p_auth_user_id and r.idempotency_key = trim(p_idempotency_key);
  if found then
    if v_existing.payload_hash = v_payload_hash then
      return query select 'already_created'::text, p_auth_user_id, v_existing.id;
    else
      return query select 'conflict'::text, null::uuid, null::uuid;
    end if;
    return;
  end if;

  if exists (select 1 from public.metra_account_states s where s.user_id = p_auth_user_id) then
    return query select 'auth_user_already_linked'::text, null::uuid, null::uuid;
    return;
  end if;
  if exists (select 1 from public.registration_requests r where r.user_id = p_auth_user_id
      and r.status in ('pending_station_approval','pending_system_approval')) then
    return query select 'existing_pending'::text, null::uuid, null::uuid;
    return;
  end if;

  select s.owner_authority_id into v_authority_id
    from public.station_catalogue s where s.id = p_station_id;
  if v_authority_id is null then
    return query select 'station_not_available'::text, null::uuid, null::uuid;
    return;
  end if;

  insert into public.metra_user_profiles(user_id, first_name, father_name, last_name, phone)
  values (p_auth_user_id, trim(p_first_name), trim(p_father_name), trim(p_last_name), nullif(trim(p_phone), ''));
  insert into public.metra_account_states(user_id, account_state, requested_by)
  values (p_auth_user_id, 'pending_station_approval', p_auth_user_id);
  insert into public.registration_requests(
    user_id, requested_station_id, requested_authority_id, requested_role_code,
    status, phone_snapshot, terms_version, terms_accepted_at, submitted_at,
    idempotency_key, payload_hash
  ) values (
    p_auth_user_id, p_station_id, v_authority_id, trim(p_role_code),
    'pending_station_approval', nullif(trim(p_phone), ''), trim(p_terms_version),
    p_submitted_at, p_submitted_at, trim(p_idempotency_key), v_payload_hash
  ) returning id into v_request_id;
  insert into public.registration_audit_events(
    request_id, user_id, actor_user_id, event_type, terms_version, occurred_at
  ) values (v_request_id, p_auth_user_id, p_auth_user_id,
            'registration_submitted', trim(p_terms_version), p_submitted_at);
  return query select 'created'::text, p_auth_user_id, v_request_id;
end;
$$;
revoke all on function public.submit_metra_registration(uuid,text,text,text,text,text,uuid,text,timestamptz,text)
  from public, anon, authenticated;
grant execute on function public.submit_metra_registration(uuid,text,text,text,text,text,uuid,text,timestamptz,text)
  to service_role;
