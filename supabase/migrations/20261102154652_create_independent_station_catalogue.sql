create extension if not exists pg_trgm with schema extensions;

create table public.countries (
  id uuid primary key default gen_random_uuid(),
  iso2_code char(2) not null unique,
  iso3_code char(3) unique,
  name_ar text not null,
  name_en text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint countries_iso2_upper check (iso2_code = upper(iso2_code)),
  constraint countries_iso3_upper check (iso3_code is null or iso3_code = upper(iso3_code)),
  constraint countries_name_ar_nonempty check (length(trim(name_ar)) > 0),
  constraint countries_name_en_nonempty check (length(trim(name_en)) > 0)
);

create table public.meteorological_authorities (
  id uuid primary key default gen_random_uuid(),
  country_id uuid not null references public.countries(id) on delete restrict,
  authority_code text not null,
  name_ar text not null,
  name_en text not null,
  is_national boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint meteorological_authorities_id_country_unique unique (id, country_id),
  constraint meteorological_authorities_code_nonempty check (length(trim(authority_code)) > 0),
  constraint meteorological_authorities_name_ar_nonempty check (length(trim(name_ar)) > 0),
  constraint meteorological_authorities_name_en_nonempty check (length(trim(name_en)) > 0),
  constraint meteorological_authorities_code_country_unique unique (country_id, authority_code)
);
create unique index meteorological_authorities_one_national_per_country
  on public.meteorological_authorities(country_id) where is_national = true;

create table public.station_catalogue (
  id uuid primary key default gen_random_uuid(),
  country_id uuid not null references public.countries(id) on delete restrict,
  owner_authority_id uuid not null,
  local_station_code text not null,
  wmo_station_id text,
  name_ar text not null,
  name_en text not null,
  station_type text not null default 'synoptic',
  operational_status text not null default 'active',
  approval_status text not null default 'pending',
  elevation_m numeric(8,2),
  timezone_name text,
  description text,
  submitted_at timestamptz,
  reviewed_at timestamptz,
  reviewed_by uuid references auth.users(id) on delete restrict,
  review_reason text,
  created_by uuid references auth.users(id) on delete restrict,
  updated_by uuid references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint station_catalogue_owner_country_fk foreign key (owner_authority_id, country_id)
    references public.meteorological_authorities(id, country_id) on delete restrict,
  constraint station_catalogue_local_code_nonempty check (length(trim(local_station_code)) > 0),
  constraint station_catalogue_name_ar_nonempty check (length(trim(name_ar)) > 0),
  constraint station_catalogue_name_en_nonempty check (length(trim(name_en)) > 0),
  constraint station_catalogue_type_nonempty check (length(trim(station_type)) > 0),
  constraint station_catalogue_operational_status_check
    check (operational_status in ('active','inactive','suspended','decommissioned')),
  constraint station_catalogue_approval_status_check
    check (approval_status in ('pending','approved','rejected','changes_requested')),
  constraint station_catalogue_elevation_check check (elevation_m is null or elevation_m between -500 and 9000),
  constraint station_catalogue_review_consistency check (approval_status = 'pending' or reviewed_at is not null)
);
create unique index station_catalogue_local_code_unique
  on public.station_catalogue(country_id, owner_authority_id, upper(local_station_code));
create unique index station_catalogue_wmo_id_unique
  on public.station_catalogue(wmo_station_id) where wmo_station_id is not null;
create index station_catalogue_country_status_idx
  on public.station_catalogue(country_id, approval_status, operational_status);
create index station_catalogue_owner_idx on public.station_catalogue(owner_authority_id);
create index station_catalogue_name_ar_trgm_idx
  on public.station_catalogue using gin (name_ar extensions.gin_trgm_ops);
create index station_catalogue_name_en_trgm_idx
  on public.station_catalogue using gin (name_en extensions.gin_trgm_ops);

create table public.station_coordinates (
  id uuid primary key default gen_random_uuid(),
  station_id uuid not null references public.station_catalogue(id) on delete restrict,
  latitude numeric(9,6) not null,
  longitude numeric(9,6) not null,
  coordinate_source text not null,
  source_reference text,
  accuracy_m numeric(10,2),
  valid_from timestamptz not null default now(),
  valid_to timestamptz,
  recorded_by uuid references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  constraint station_coordinates_latitude_check check (latitude between -90 and 90),
  constraint station_coordinates_longitude_check check (longitude between -180 and 180),
  constraint station_coordinates_source_check check (coordinate_source in ('official_record','field_survey','gps','manual_verified','other')),
  constraint station_coordinates_accuracy_check check (accuracy_m is null or accuracy_m >= 0),
  constraint station_coordinates_validity_check check (valid_to is null or valid_to > valid_from)
);
create unique index station_coordinates_one_current_per_station
  on public.station_coordinates(station_id) where valid_to is null;
create index station_coordinates_location_idx on public.station_coordinates(latitude, longitude);

create table public.station_access_grants (
  id uuid primary key default gen_random_uuid(),
  station_id uuid not null references public.station_catalogue(id) on delete restrict,
  authority_id uuid not null references public.meteorological_authorities(id) on delete restrict,
  access_level text not null,
  valid_from timestamptz not null default now(),
  valid_to timestamptz,
  approval_status text not null default 'pending',
  granted_by uuid references auth.users(id) on delete restrict,
  reason text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint station_access_grants_level_check check (access_level in ('read_only','report_entry','station_editor','station_admin')),
  constraint station_access_grants_approval_check check (approval_status in ('pending','approved','rejected','revoked')),
  constraint station_access_grants_validity_check check (valid_to is null or valid_to > valid_from),
  constraint station_access_grants_reason_nonempty check (length(trim(reason)) > 0)
);
create unique index station_access_grants_one_pending_or_active
  on public.station_access_grants(station_id, authority_id) where approval_status in ('pending','approved');

create table public.station_audit_log (
  id bigint generated always as identity primary key,
  entity_type text not null,
  entity_id uuid not null,
  action text not null,
  actor_id uuid references auth.users(id) on delete restrict,
  reason text,
  before_data jsonb,
  after_data jsonb,
  occurred_at timestamptz not null default now(),
  constraint station_audit_entity_type_check check (entity_type in ('country','authority','station','coordinate','access_grant')),
  constraint station_audit_action_nonempty check (length(trim(action)) > 0)
);
create index station_audit_entity_history_idx
  on public.station_audit_log(entity_type, entity_id, occurred_at desc);
create index station_audit_occurred_at_idx on public.station_audit_log(occurred_at desc);

alter table public.countries enable row level security;
alter table public.meteorological_authorities enable row level security;
alter table public.station_catalogue enable row level security;
alter table public.station_coordinates enable row level security;
alter table public.station_access_grants enable row level security;
alter table public.station_audit_log enable row level security;

revoke all on table public.countries, public.meteorological_authorities, public.station_catalogue,
  public.station_coordinates, public.station_access_grants, public.station_audit_log from anon, authenticated;
grant all on table public.countries, public.meteorological_authorities, public.station_catalogue,
  public.station_coordinates, public.station_access_grants, public.station_audit_log to service_role;

comment on table public.station_catalogue is
  'METRA 2027 operational station catalogue; sole operational source for directory, map, search and filters; legacy datasets are excluded.';
comment on table public.station_coordinates is 'Verified effective-dated station coordinates; one current record per station.';
comment on table public.station_access_grants is 'Time-bounded authority-level station access grants subject to explicit approval.';
comment on table public.station_audit_log is 'Audit history for station catalogue administration.';
