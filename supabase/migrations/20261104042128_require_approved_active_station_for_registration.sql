-- Prevent registration requests from being created against stations that
-- cannot enter the two-stage review queue yet. The UI mirrors this rule,
-- but the database remains the authoritative enforcement point.

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
returns table(result_status text, account_id uuid, request_id uuid)
language plpgsql
security definer
set search_path = pg_catalog, public, auth, private
as $function$
declare
  v_authority_id uuid;
begin
  if p_auth_user_id is null then
    raise exception 'registration_user_missing' using errcode = '22023';
  end if;
  if p_terms_version is distinct from 'metra-terms-2026-11' then
    return query select 'terms_version_invalid'::text, null::uuid, null::uuid;
    return;
  end if;
  if not exists (
    select 1 from public.metra_role_catalogue r
     where r.role_code = trim(p_role_code)
       and r.is_active = true and r.is_requestable = true
  ) then
    return query select 'role_not_requestable'::text, null::uuid, null::uuid;
    return;
  end if;
  select s.owner_authority_id into v_authority_id
    from public.station_catalogue s
    join public.meteorological_authorities a on a.id = s.owner_authority_id
   where s.id = p_station_id
     and s.is_demo = false
     and s.approval_status = 'approved'
     and s.operational_status = 'active'
     and a.is_active = true;
  if v_authority_id is null then
    return query select 'station_not_available'::text, null::uuid, null::uuid;
    return;
  end if;
  return query
    select r.result_status, r.account_id, r.request_id
      from private.submit_metra_registration(
        p_auth_user_id, p_first_name, p_father_name, p_last_name, p_phone,
        p_role_code, p_station_id, p_terms_version, clock_timestamp(), p_idempotency_key
      ) r;
end;
$function$;
