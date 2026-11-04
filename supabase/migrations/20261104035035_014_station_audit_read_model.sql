-- Read-only, station-scoped audit projection for station catalogue and assignment events.
-- Raw station_audit_log remains inaccessible to browser roles.
CREATE OR REPLACE FUNCTION public.get_station_audit_log(
  p_station_id uuid,
  p_limit integer DEFAULT 100
)
RETURNS SETOF jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public'
AS $function$
BEGIN
  IF p_station_id IS NULL OR p_limit IS NULL OR p_limit < 1 OR p_limit > 250 THEN
    RAISE EXCEPTION 'invalid_station_audit_query' USING ERRCODE = '22023';
  END IF;

  RETURN QUERY
  SELECT jsonb_build_object(
    'id', log.id,
    'entity_type', log.entity_type,
    'entity_id', log.entity_id,
    'action', log.action,
    'actor_id', log.actor_id,
    'reason', log.reason,
    'occurred_at', log.occurred_at,
    'target_user_id', COALESCE(log.after_data ->> 'user_id', log.before_data ->> 'user_id'),
    'role_code', COALESCE(
      log.after_data ->> 'assignment_role_code',
      log.after_data ->> 'role_code',
      log.before_data ->> 'assignment_role_code',
      log.before_data ->> 'role_code'
    ),
    'previous_status', log.before_data ->> 'approval_status',
    'resulting_status', log.after_data ->> 'approval_status',
    'valid_from', COALESCE(log.after_data ->> 'valid_from', log.before_data ->> 'valid_from'),
    'valid_to', COALESCE(log.after_data ->> 'valid_to', log.before_data ->> 'valid_to')
  )
  FROM public.station_audit_log AS log
  WHERE
    (log.entity_type = 'station' AND log.entity_id = p_station_id)
    OR (
      log.entity_type = 'station_assignment'
      AND COALESCE(log.after_data ->> 'station_id', log.before_data ->> 'station_id') = p_station_id::text
    )
  ORDER BY log.occurred_at DESC, log.id DESC
  LIMIT p_limit;
END;
$function$;

REVOKE ALL ON FUNCTION public.get_station_audit_log(uuid, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_station_audit_log(uuid, integer) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_station_audit_log(uuid, integer) TO service_role;
