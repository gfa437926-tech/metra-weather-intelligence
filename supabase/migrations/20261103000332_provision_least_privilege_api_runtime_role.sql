-- Non-login role for the ASP.NET runtime. Provision a separate managed login
-- and grant membership outside this migration; never use postgres/service_role.
do $$
begin
  if not exists (select 1 from pg_catalog.pg_roles where rolname = 'metra_api_runtime') then
    create role metra_api_runtime nologin nosuperuser nocreatedb nocreaterole noreplication;
  end if;
end
$$;

grant usage on schema public to metra_api_runtime;
grant select on
  public.metra_account_states,
  public.metra_user_profiles,
  public.station_assignments,
  public.permission_grants,
  public.station_catalogue,
  public.meteorological_authorities,
  public.metra_role_catalogue
to metra_api_runtime;

create policy metra_account_states_api_runtime_read
  on public.metra_account_states for select to metra_api_runtime using (true);
create policy metra_user_profiles_api_runtime_read
  on public.metra_user_profiles for select to metra_api_runtime using (true);
create policy station_assignments_api_runtime_read
  on public.station_assignments for select to metra_api_runtime using (true);
create policy permission_grants_api_runtime_read
  on public.permission_grants for select to metra_api_runtime using (true);
create policy station_catalogue_api_runtime_read
  on public.station_catalogue for select to metra_api_runtime using (true);
create policy meteorological_authorities_api_runtime_read
  on public.meteorological_authorities for select to metra_api_runtime using (true);
create policy metra_role_catalogue_api_runtime_read
  on public.metra_role_catalogue for select to metra_api_runtime using (true);

revoke execute on function public.submit_metra_registration(
  uuid, text, text, text, text, text, uuid, text, timestamptz, text
) from service_role;
grant execute on function public.submit_metra_registration(
  uuid, text, text, text, text, text, uuid, text, timestamptz, text
) to metra_api_runtime;

comment on role metra_api_runtime is
  'Non-login least-privilege role for METRA ASP.NET API. Provision a separate managed login and grant membership; never connect as project owner or service_role.';
