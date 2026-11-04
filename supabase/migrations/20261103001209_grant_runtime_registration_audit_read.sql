-- Allow the trusted API runtime to read approval-stage evidence for separation
-- of duties. Browser roles remain denied and RLS remains enabled.
grant select on public.registration_audit_events to metra_api_runtime;
create policy registration_audit_events_api_runtime_read
  on public.registration_audit_events for select to metra_api_runtime using (true);
