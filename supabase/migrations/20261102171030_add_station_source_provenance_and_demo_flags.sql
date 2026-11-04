alter table public.station_catalogue
  add column source_system text not null default 'metra2027',
  add column source_table text,
  add column source_record_id text,
  add column is_demo boolean not null default false;

alter table public.station_catalogue
  add constraint station_catalogue_source_provenance_check
  check (
    (source_table is null and source_record_id is null)
    or
    (length(btrim(source_table)) > 0 and length(btrim(source_record_id)) > 0)
  );

create unique index station_catalogue_source_identity_uidx
  on public.station_catalogue (source_system, source_table, source_record_id)
  where source_table is not null and source_record_id is not null;

comment on column public.station_catalogue.source_system is
  'Origin system for this station record; used for traceable, repeatable, non-destructive imports.';
comment on column public.station_catalogue.source_table is
  'Origin table name in source system; NULL for manually curated records.';
comment on column public.station_catalogue.source_record_id is
  'Original source record identifier, stored as text to preserve source keys.';
comment on column public.station_catalogue.is_demo is
  'True only for clearly synthetic demonstration/test records; never represents an operational station.';
