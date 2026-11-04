-- Keep the source of the already-applied migration 20261104024652
-- synchronized with production schema history.
create or replace function private.decide_station_catalogue_review(
  p_station_id uuid,
  p_expected_status text,
  p_actor_user_id uuid,
  p_decision text,
  p_reason text,
  p_occurred_at timestamptz
)
returns table(result_status text, resulting_status text)
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $function$
declare
  v_station public.station_catalogue%rowtype;
  v_now timestamptz := clock_timestamp();
begin
  if p_station_id is null
    or p_actor_user_id is null
    or p_expected_status is distinct from 'pending'
    or p_decision is null
    or p_decision not in ('approved', 'rejected', 'changes_requested')
    or length(trim(coalesce(p_reason, ''))) < 5
    or length(p_reason) > 2000 then
    raise exception 'invalid_station_review_request' using errcode = '22023';
  end if;

  if not exists (
    select 1 from public.metra_account_states a
    where a.user_id = p_actor_user_id and a.account_state = 'active'
  ) then
    raise exception 'reviewer_account_not_active' using errcode = '42501';
  end if;

  if not exists (
    select 1 from public.permission_grants g
    where g.user_id = p_actor_user_id
      and g.permission_code = 'stations.catalogue.review'
      and g.approval_status = 'approved'
      and g.revoked_at is null
      and g.valid_from <= v_now
      and (g.valid_to is null or g.valid_to > v_now)
  ) then
    raise exception 'station_review_permission_denied' using errcode = '42501';
  end if;

  select * into v_station
  from public.station_catalogue
  where id = p_station_id and is_demo = false
  for update;

  if not found then
    raise exception 'station_not_found' using errcode = 'P0002';
  end if;

  if v_station.approval_status is distinct from p_expected_status then
    return query select 'state_conflict'::text, v_station.approval_status;
    return;
  end if;

  update public.station_catalogue
  set approval_status = p_decision,
      reviewed_at = v_now,
      reviewed_by = p_actor_user_id,
      review_reason = trim(p_reason),
      updated_at = v_now,
      updated_by = p_actor_user_id
  where id = p_station_id;

  insert into public.station_audit_log(
    entity_type, entity_id, action, actor_id, reason,
    before_data, after_data, occurred_at
  )
  values (
    'station', p_station_id, 'catalogue_' || p_decision,
    p_actor_user_id, trim(p_reason),
    jsonb_build_object(
      'approval_status', v_station.approval_status,
      'operational_status', v_station.operational_status
    ),
    jsonb_build_object(
      'approval_status', p_decision,
      'operational_status', v_station.operational_status,
      'review_reason', trim(p_reason)
    ),
    v_now
  );

  return query select 'updated'::text, p_decision;
end;
$function$;

revoke all on function private.decide_station_catalogue_review(uuid, text, uuid, text, text, timestamptz)
  from public, anon, authenticated, service_role;
