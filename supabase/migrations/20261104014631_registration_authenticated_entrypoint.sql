-- Safe authenticated registration entry point.
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
  if auth.uid() is null or auth.uid() <> p_auth_user_id then
    raise exception 'registration_user_mismatch' using errcode = '42501';
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
        p_role_code, p_station_id, p_terms_version, p_submitted_at, p_idempotency_key
      ) r;
end;
$function$;
revoke all on function public.submit_metra_registration(uuid,text,text,text,text,text,uuid,text,timestamptz,text) from public;
revoke all on function public.submit_metra_registration(uuid,text,text,text,text,text,uuid,text,timestamptz,text) from anon;
grant execute on function public.submit_metra_registration(uuid,text,text,text,text,text,uuid,text,timestamptz,text) to authenticated;
