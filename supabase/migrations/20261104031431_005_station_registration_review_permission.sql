-- Station heads are responsible for station-level staff and station operations.
-- This allow-list entry does not grant a permission by itself: an active account,
-- approved station assignment and a separately approved, time-valid individual
-- permission_grants row are still required by the station authorization RPC.
INSERT INTO public.metra_role_permissions (role_code, permission_code)
VALUES ('station_head', 'registrations.station.approve')
ON CONFLICT (role_code, permission_code) DO NOTHING;
