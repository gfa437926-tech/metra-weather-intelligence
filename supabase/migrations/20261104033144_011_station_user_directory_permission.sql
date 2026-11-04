-- Read-only station staff directory access for station heads and system administrators.
-- Each request still requires an approved, time-valid individual permission grant
-- and an approved assignment to the exact station.
INSERT INTO public.metra_role_permissions (role_code, permission_code)
VALUES
  ('station_head', 'users.station.view'),
  ('system_admin', 'users.station.view')
ON CONFLICT (role_code, permission_code) DO NOTHING;
