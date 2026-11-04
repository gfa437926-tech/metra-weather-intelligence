alter table public.station_catalogue
  drop constraint station_catalogue_operational_status_check;
alter table public.station_catalogue
  add constraint station_catalogue_operational_status_check
  check (operational_status = any (array['active','inactive','suspended','decommissioned','unverified']));
