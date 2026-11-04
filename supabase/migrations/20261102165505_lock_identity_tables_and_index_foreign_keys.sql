create policy metra_account_states_deny_clients on public.metra_account_states
  for all to anon, authenticated using (false) with check (false);
create policy authority_memberships_deny_clients on public.authority_memberships
  for all to anon, authenticated using (false) with check (false);
create policy station_assignments_deny_clients on public.station_assignments
  for all to anon, authenticated using (false) with check (false);
create policy permission_grants_deny_clients on public.permission_grants
  for all to anon, authenticated using (false) with check (false);

create index metra_account_states_reviewed_by_idx on public.metra_account_states(reviewed_by);
create index authority_memberships_requested_by_idx on public.authority_memberships(requested_by);
create index authority_memberships_approved_by_idx on public.authority_memberships(approved_by);
create index station_assignments_requested_by_idx on public.station_assignments(requested_by);
create index station_assignments_approved_by_idx on public.station_assignments(approved_by);
create index station_assignments_station_authority_idx on public.station_assignments(station_id, authority_id);
create index permission_grants_requested_by_idx on public.permission_grants(requested_by);
create index permission_grants_approved_by_idx on public.permission_grants(approved_by);
