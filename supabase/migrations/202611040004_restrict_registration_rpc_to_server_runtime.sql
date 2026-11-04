-- Only trusted Edge Functions using the service role may execute these SECURITY DEFINER wrappers.
-- Edge Functions verify the user's JWT first; the private transactions then validate
-- the submitted actor against active account state, direct grants and station assignment.
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
   where s.id = p_station_id and s.is_demo = false and a.is_active = true;
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
revoke all on function public.submit_metra_registration(uuid,text,text,text,text,text,uuid,text,timestamptz,text) from public;
revoke all on function public.submit_metra_registration(uuid,text,text,text,text,text,uuid,text,timestamptz,text) from anon;
revoke all on function public.submit_metra_registration(uuid,text,text,text,text,text,uuid,text,timestamptz,text) from authenticated;
grant execute on function public.submit_metra_registration(uuid,text,text,text,text,text,uuid,text,timestamptz,text) to service_role;

create or replace function public.decide_metra_registration(
  p_request_id uuid,
  p_expected_status text,
  p_actor_user_id uuid,
  p_decision text,
  p_note text,
  p_occurred_at timestamptz
)
returns table(result_status text, resulting_status text)
language plpgsql
security definer
set search_path = pg_catalog, public, auth, private
as $function$
begin
  if p_actor_user_id is null then
    raise exception 'registration_decision_actor_missing' using errcode = '22023';
  end if;
  if p_expected_status not in ('pending_station_approval','pending_system_approval') then
    raise exception 'invalid_registration_stage' using errcode = '22023';
  end if;
  if p_decision not in ('approve','reject') then
    raise exception 'invalid_registration_decision' using errcode = '22023';
  end if;
  return query
    select d.result_status, d.resulting_status
      from private.decide_metra_registration(
        p_request_id, p_expected_status, p_actor_user_id,
        p_decision, p_note, clock_timestamp()
      ) d;
end;
$function$;
revoke all on function public.decide_metra_registration(uuid,text,uuid,text,text,timestamptz) from public;
revoke all on function public.decide_metra_registration(uuid,text,uuid,text,text,timestamptz) from anon;
revoke all on function public.decide_metra_registration(uuid,text,uuid,text,text,timestamptz) from authenticated;
grant execute on function public.decide_metra_registration(uuid,text,uuid,text,text,timestamptz) to service_role;
