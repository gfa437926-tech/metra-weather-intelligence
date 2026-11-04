-- Cover the remaining registration foreign keys with narrow lookup indexes.
-- Existing queue/history indexes are retained; these indexes support FK joins and parent-key maintenance.
create index if not exists registration_audit_actor_user_idx
  on public.registration_audit_events(actor_user_id);

create index if not exists registration_requests_requested_role_idx
  on public.registration_requests(requested_role_code);

create index if not exists registration_requests_reviewed_by_idx
  on public.registration_requests(reviewed_by);

create index if not exists registration_requests_station_authority_idx
  on public.registration_requests(requested_station_id, requested_authority_id);
