-- Reconstructed source for the already-applied migration 20261104030506.
-- Grants the catalogue review permission to the non-requestable network director role.
-- This is role capability metadata only; it does not create users or individual grants.

insert into public.metra_role_permissions (role_code, permission_code)
values ('network_director', 'stations.catalogue.review')
on conflict (role_code, permission_code) do nothing;
