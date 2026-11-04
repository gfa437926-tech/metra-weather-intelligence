do $$
declare
  t text;
  policy_name text;
begin
  foreach t in array array[
    'countries',
    'meteorological_authorities',
    'station_catalogue',
    'station_coordinates',
    'station_access_grants',
    'station_audit_log'
  ] loop
    policy_name := t || '_deny_client_access';
    if not exists (
      select 1 from pg_catalog.pg_policies
      where schemaname = 'public'
        and tablename = t
        and policyname = policy_name
    ) then
      execute format(
        'create policy %I on public.%I as permissive for all to anon, authenticated using (false) with check (false)',
        policy_name, t
      );
    end if;
  end loop;
end
$$;
revoke all on schema private from public, anon, authenticated;
