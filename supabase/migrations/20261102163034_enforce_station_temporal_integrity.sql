create extension if not exists btree_gist with schema extensions;

drop index if exists public.station_access_grants_one_pending_or_active;

alter table public.station_coordinates
  add constraint station_coordinates_no_overlapping_periods
  exclude using gist (
    station_id with =,
    tstzrange(valid_from, coalesce(valid_to, 'infinity'::timestamptz), '[)') with &&
  );

alter table public.station_access_grants
  add constraint station_access_grants_no_overlapping_approved_periods
  exclude using gist (
    station_id with =,
    authority_id with =,
    tstzrange(valid_from, coalesce(valid_to, 'infinity'::timestamptz), '[)') with &&
  )
  where (approval_status in ('pending','approved'));

alter table public.station_coordinates
  add constraint station_coordinates_official_reference_required
  check (coordinate_source <> 'official_record' or length(trim(coalesce(source_reference, ''))) > 0);

alter table public.station_catalogue
  add constraint station_catalogue_review_actor_consistency
  check ((reviewed_at is null) = (reviewed_by is null));

alter table public.station_catalogue
  add constraint station_catalogue_review_reason_required
  check (approval_status = 'pending' or length(trim(coalesce(review_reason, ''))) > 0);
