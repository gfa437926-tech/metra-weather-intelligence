-- System-stage registration approval is deliberately limited to the
-- non-requestable system_admin role. A separate approved individual grant,
-- active account, station assignment and distinct second reviewer are still
-- enforced by the station authorization and registration decision functions.
INSERT INTO public.metra_role_permissions (role_code, permission_code)
VALUES ('system_admin', 'registrations.system.approve')
ON CONFLICT (role_code, permission_code) DO NOTHING;
