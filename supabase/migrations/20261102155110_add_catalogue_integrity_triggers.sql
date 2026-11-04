create schema if not exists private;

create or replace function private.set_updated_at()
returns trigger
language plpgsql
set search_path = pg_catalog
as $$
begin
  new.updated_at := pg_catalog.now();
  return new;
end;
$$;
revoke all on function private.set_updated_at() from public, anon, authenticated;

create trigger countries_set_updated_at before update on public.countries
for each row execute function private.set_updated_at();
create trigger meteorological_authorities_set_updated_at before update on public.meteorological_authorities
for each row execute function private.set_updated_at();
create trigger station_catalogue_set_updated_at before update on public.station_catalogue
for each row execute function private.set_updated_at();
create trigger station_access_grants_set_updated_at before update on public.station_access_grants
for each row execute function private.set_updated_at();

create or replace function private.prevent_audit_log_mutation()
returns trigger
language plpgsql
set search_path = pg_catalog
as $$
begin
  raise exception 'station_audit_log is append-only';
end;
$$;
revoke all on function private.prevent_audit_log_mutation() from public, anon, authenticated;

create trigger station_audit_log_prevent_update before update or delete on public.station_audit_log
for each row execute function private.prevent_audit_log_mutation();
