create index if not exists station_catalogue_owner_country_idx
  on public.station_catalogue(owner_authority_id, country_id);
create index if not exists station_catalogue_created_by_idx
  on public.station_catalogue(created_by);
create index if not exists station_catalogue_reviewed_by_idx
  on public.station_catalogue(reviewed_by);
create index if not exists station_catalogue_updated_by_idx
  on public.station_catalogue(updated_by);
create index if not exists station_access_grants_authority_idx
  on public.station_access_grants(authority_id);
create index if not exists station_access_grants_granted_by_idx
  on public.station_access_grants(granted_by);
create index if not exists station_audit_log_actor_idx
  on public.station_audit_log(actor_id);
create index if not exists station_coordinates_recorded_by_idx
  on public.station_coordinates(recorded_by);
