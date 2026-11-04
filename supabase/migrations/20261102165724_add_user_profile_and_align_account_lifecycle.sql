create table public.metra_user_profiles (
  user_id uuid primary key references auth.users(id) on delete restrict,
  first_name text not null,
  father_name text,
  last_name text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint metra_user_profiles_first_name_check
    check (length(trim(first_name)) between 1 and 128 and first_name = trim(first_name)),
  constraint metra_user_profiles_father_name_check
    check (father_name is null or (length(trim(father_name)) between 1 and 128 and father_name = trim(father_name))),
  constraint metra_user_profiles_last_name_check
    check (length(trim(last_name)) between 1 and 128 and last_name = trim(last_name))
);

alter table public.metra_account_states
  add column requested_by uuid references auth.users(id) on delete restrict;

alter table public.metra_account_states
  drop constraint metra_account_states_state_check,
  drop constraint metra_account_states_reason_required,
  drop constraint metra_account_states_review_consistency;

alter table public.metra_account_states
  add constraint metra_account_states_state_check
    check (account_state in ('pending_station_approval','pending_system_approval','active','suspended','rejected','disabled')),
  add constraint metra_account_states_requester_required
    check (requested_by is not null),
  add constraint metra_account_states_review_consistency
    check (
      (account_state in ('pending_station_approval','pending_system_approval')
        and reviewed_by is null and reviewed_at is null)
      or
      (account_state in ('active','suspended','rejected','disabled')
        and reviewed_by is not null and reviewed_at is not null
        and reviewed_by <> requested_by)
    ),
  add constraint metra_account_states_reason_required
    check (account_state not in ('suspended','rejected','disabled')
      or length(trim(coalesce(state_reason,''))) > 0);

create trigger metra_user_profiles_set_updated_at
  before update on public.metra_user_profiles
  for each row execute function private.set_updated_at();

alter table public.metra_user_profiles enable row level security;
revoke all on table public.metra_user_profiles from anon, authenticated;
grant all on table public.metra_user_profiles to service_role;
create policy metra_user_profiles_deny_clients on public.metra_user_profiles
  for all to anon, authenticated using (false) with check (false);

comment on table public.metra_user_profiles is
  'METRA-controlled user name profile; identity and authorization still derive from validated server authentication and authoritative database records.';
