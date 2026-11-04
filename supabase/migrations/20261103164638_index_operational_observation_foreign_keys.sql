create index if not exists metra_observation_audit_actor_user_idx
  on public.metra_observation_audit_events (actor_user_id);
create index if not exists metra_observation_audit_station_idx
  on public.metra_observation_audit_events (station_id);
create index if not exists metra_observations_reviewed_by_idx
  on public.metra_observations (reviewed_by);
