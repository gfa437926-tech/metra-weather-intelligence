create policy metra_observations_deny_client_access
on public.metra_observations
for all to anon, authenticated
using (false)
with check (false);

create policy metra_observation_audit_deny_client_access
on public.metra_observation_audit_events
for all to anon, authenticated
using (false)
with check (false);
