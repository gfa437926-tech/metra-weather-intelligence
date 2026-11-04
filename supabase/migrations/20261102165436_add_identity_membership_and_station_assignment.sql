-- METRA 2027 identity and scoped assignment foundation.
-- All client roles remain denied; only a trusted backend may evaluate these facts.
alter table public.station_catalogue
  add constraint station_catalogue_id_owner_authority_unique
  unique (id, owner_authority_id);

create table public.metra_account_states (
  user_id uuid primary key references auth.users(id) on delete restrict,
  account_state text not null default 'pending',
  state_reason text,
  reviewed_by uuid references auth.users(id) on delete restrict,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint metra_account_states_state_check
    check (account_state in ('pending','active','suspended','disabled')),
  constraint metra_account_states_review_consistency
    check ((reviewed_by is null) = (reviewed_at is null)),
  constraint metra_account_states_reason_required
    check (account_state = 'pending' or length(trim(coalesce(state_reason,''))) > 0)
);

create table public.authority_memberships (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete restrict,
  authority_id uuid not null references public.meteorological_authorities(id) on delete restrict,
  membership_role_code text not null,
  approval_status text not null default 'pending',
  valid_from timestamptz not null default now(),
  valid_to timestamptz,
  requested_by uuid not null references auth.users(id) on delete restrict,
  approved_by uuid references auth.users(id) on delete restrict,
  reviewed_at timestamptz,
  reason text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint authority_memberships_role_nonempty check (length(trim(membership_role_code)) > 0),
  constraint authority_memberships_status_check
    check (approval_status in ('pending','approved','rejected','revoked')),
  constraint authority_memberships_validity_check check (valid_to is null or valid_to > valid_from),
  constraint authority_memberships_review_consistency
    check ((approved_by is null) = (reviewed_at is null)),
  constraint authority_memberships_no_self_approval
    check (approved_by is null or approved_by <> requested_by),
  constraint authority_memberships_reason_nonempty check (length(trim(reason)) > 0),
  constraint authority_memberships_no_overlapping_periods
    exclude using gist (
      user_id with =,
      authority_id with =,
      tstzrange(valid_from, valid_to, '[)') with &&
    ) where (approval_status in ('pending','approved'))
);

create table public.station_assignments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete restrict,
  station_id uuid not null,
  authority_id uuid not null,
  assignment_role_code text not null,
  approval_status text not null default 'pending',
  valid_from timestamptz not null default now(),
  valid_to timestamptz,
  requested_by uuid not null references auth.users(id) on delete restrict,
  approved_by uuid references auth.users(id) on delete restrict,
  reviewed_at timestamptz,
  reason text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint station_assignments_station_authority_fk
    foreign key (station_id, authority_id)
    references public.station_catalogue(id, owner_authority_id) on delete restrict,
  constraint station_assignments_role_nonempty check (length(trim(assignment_role_code)) > 0),
  constraint station_assignments_status_check
    check (approval_status in ('pending','approved','rejected','revoked')),
  constraint station_assignments_validity_check check (valid_to is null or valid_to > valid_from),
  constraint station_assignments_review_consistency
    check ((approved_by is null) = (reviewed_at is null)),
  constraint station_assignments_no_self_approval
    check (approved_by is null or approved_by <> requested_by),
  constraint station_assignments_reason_nonempty check (length(trim(reason)) > 0),
  constraint station_assignments_no_overlapping_periods
    exclude using gist (
      user_id with =,
      station_id with =,
      tstzrange(valid_from, valid_to, '[)') with &&
    ) where (approval_status in ('pending','approved'))
);

create table public.permission_grants (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete restrict,
  permission_code text not null,
  approval_status text not null default 'pending',
  valid_from timestamptz not null default now(),
  valid_to timestamptz,
  revoked_at timestamptz,
  requested_by uuid not null references auth.users(id) on delete restrict,
  approved_by uuid references auth.users(id) on delete restrict,
  reviewed_at timestamptz,
  reason text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint permission_grants_code_nonempty check (length(trim(permission_code)) > 0),
  constraint permission_grants_status_check
    check (approval_status in ('pending','approved','rejected','revoked')),
  constraint permission_grants_validity_check check (valid_to is null or valid_to > valid_from),
  constraint permission_grants_revocation_check check (revoked_at is null or revoked_at >= valid_from),
  constraint permission_grants_review_consistency
    check ((approved_by is null) = (reviewed_at is null)),
  constraint permission_grants_no_self_approval
    check (approved_by is null or approved_by <> requested_by),
  constraint permission_grants_reason_nonempty check (length(trim(reason)) > 0),
  constraint permission_grants_no_overlapping_periods
    exclude using gist (
      user_id with =,
      permission_code with =,
      tstzrange(valid_from, valid_to, '[)') with &&
    ) where (approval_status in ('pending','approved'))
);

create index authority_memberships_authority_status_idx
  on public.authority_memberships(authority_id, approval_status, user_id);
create index authority_memberships_user_status_idx
  on public.authority_memberships(user_id, approval_status, authority_id);
create index station_assignments_station_status_idx
  on public.station_assignments(station_id, approval_status, user_id);
create index station_assignments_user_status_idx
  on public.station_assignments(user_id, approval_status, station_id);
create index permission_grants_user_code_status_idx
  on public.permission_grants(user_id, permission_code, approval_status);

create trigger metra_account_states_set_updated_at
  before update on public.metra_account_states
  for each row execute function private.set_updated_at();
create trigger authority_memberships_set_updated_at
  before update on public.authority_memberships
  for each row execute function private.set_updated_at();
create trigger station_assignments_set_updated_at
  before update on public.station_assignments
  for each row execute function private.set_updated_at();
create trigger permission_grants_set_updated_at
  before update on public.permission_grants
  for each row execute function private.set_updated_at();

alter table public.metra_account_states enable row level security;
alter table public.authority_memberships enable row level security;
alter table public.station_assignments enable row level security;
alter table public.permission_grants enable row level security;

revoke all on table public.metra_account_states, public.authority_memberships,
  public.station_assignments, public.permission_grants from anon, authenticated;
grant all on table public.metra_account_states, public.authority_memberships,
  public.station_assignments, public.permission_grants to service_role;

comment on table public.metra_account_states is
  'Authoritative METRA account lifecycle state; user-editable auth metadata is not an authorization source.';
comment on table public.authority_memberships is
  'Time-bounded, reviewed membership of an authenticated user in a meteorological authority.';
comment on table public.station_assignments is
  'Exact station-scoped user assignment; approval and membership are independently verified by the trusted backend.';
comment on table public.permission_grants is
  'Time-bounded, reviewed METRA action permissions; backend must validate account state and resource scope in one consistent snapshot.';

alter table public.station_audit_log
  drop constraint station_audit_entity_type_check;
alter table public.station_audit_log
  add constraint station_audit_entity_type_check
  check (entity_type in ('country','authority','station','coordinate','access_grant',
                         'account_state','authority_membership','station_assignment','permission_grant'));
