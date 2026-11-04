-- Server-only, station-filtered read models for registration review.
-- The functions join the profile by user_id explicitly; registration_requests
-- intentionally has no direct FK to metra_user_profiles.
CREATE OR REPLACE FUNCTION public.get_station_registration_queue(
  p_station_id uuid,
  p_expected_status text,
  p_limit integer DEFAULT 50
)
RETURNS SETOF jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public'
AS $function$
BEGIN
  IF p_station_id IS NULL
     OR p_expected_status NOT IN ('pending_station_approval', 'pending_system_approval')
     OR p_limit IS NULL OR p_limit < 1 OR p_limit > 100 THEN
    RAISE EXCEPTION 'invalid_registration_queue_query' USING ERRCODE = '22023';
  END IF;

  RETURN QUERY
    SELECT jsonb_build_object(
      'id', r.id,
      'user_id', r.user_id,
      'requested_station_id', r.requested_station_id,
      'requested_role_code', r.requested_role_code,
      'status', r.status,
      'phone_snapshot', r.phone_snapshot,
      'terms_version', r.terms_version,
      'submitted_at', r.submitted_at,
      'metra_user_profiles', CASE WHEN p.user_id IS NULL THEN NULL ELSE jsonb_build_object(
        'first_name', p.first_name,
        'father_name', p.father_name,
        'last_name', p.last_name
      ) END,
      'metra_role_catalogue', jsonb_build_object(
        'name_ar', role.name_ar,
        'name_en', role.name_en
      ),
      'station_catalogue', jsonb_build_object(
        'name_ar', station.name_ar,
        'name_en', station.name_en,
        'local_station_code', station.local_station_code
      )
    )
    FROM public.registration_requests AS r
    LEFT JOIN public.metra_user_profiles AS p ON p.user_id = r.user_id
    JOIN public.metra_role_catalogue AS role ON role.role_code = r.requested_role_code
    JOIN public.station_catalogue AS station ON station.id = r.requested_station_id
    WHERE r.requested_station_id = p_station_id
      AND r.status = p_expected_status
    ORDER BY r.submitted_at ASC, r.id ASC
    LIMIT p_limit;
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_station_registration_audit(
  p_station_id uuid,
  p_limit integer DEFAULT 100
)
RETURNS SETOF jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public'
AS $function$
BEGIN
  IF p_station_id IS NULL OR p_limit IS NULL OR p_limit < 1 OR p_limit > 200 THEN
    RAISE EXCEPTION 'invalid_registration_audit_query' USING ERRCODE = '22023';
  END IF;

  RETURN QUERY
    SELECT jsonb_build_object(
      'id', e.id,
      'request_id', e.request_id,
      'user_id', e.user_id,
      'actor_user_id', e.actor_user_id,
      'event_type', e.event_type,
      'terms_version', e.terms_version,
      'decision_note', e.decision_note,
      'occurred_at', e.occurred_at
    )
    FROM public.registration_audit_events AS e
    JOIN public.registration_requests AS r ON r.id = e.request_id
    WHERE r.requested_station_id = p_station_id
    ORDER BY e.occurred_at DESC, e.id DESC
    LIMIT p_limit;
END;
$function$;

REVOKE ALL ON FUNCTION public.get_station_registration_queue(uuid, text, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_station_registration_queue(uuid, text, integer) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_station_registration_queue(uuid, text, integer) TO service_role;

REVOKE ALL ON FUNCTION public.get_station_registration_audit(uuid, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_station_registration_audit(uuid, integer) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_station_registration_audit(uuid, integer) TO service_role;
