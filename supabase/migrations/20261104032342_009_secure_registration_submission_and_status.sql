-- Restrict public registration submission to approved, active, non-demo stations.
-- The authenticated user id is supplied only by the API from the verified JWT.
CREATE OR REPLACE FUNCTION public.submit_metra_registration_for_active_station(
  p_auth_user_id uuid,
  p_first_name text,
  p_father_name text,
  p_last_name text,
  p_phone text,
  p_role_code text,
  p_station_id uuid,
  p_terms_version text,
  p_submitted_at timestamp with time zone,
  p_idempotency_key text
)
RETURNS TABLE(result_status text, account_id uuid, request_id uuid)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public', 'private'
AS $function$
DECLARE
  v_station_id uuid;
BEGIN
  IF p_auth_user_id IS NULL OR p_auth_user_id = '00000000-0000-0000-0000-000000000000'::uuid THEN
    RAISE EXCEPTION 'registration_user_missing' USING ERRCODE = '22023';
  END IF;

  SELECT s.id INTO v_station_id
    FROM public.station_catalogue AS s
    JOIN public.meteorological_authorities AS a ON a.id = s.owner_authority_id
   WHERE s.id = p_station_id
     AND s.approval_status = 'approved'
     AND s.operational_status = 'active'
     AND s.is_demo = false
     AND a.is_active = true
   FOR SHARE OF s, a;

  IF v_station_id IS NULL THEN
    RETURN QUERY SELECT 'station_not_available'::text, NULL::uuid, NULL::uuid;
    RETURN;
  END IF;

  RETURN QUERY
    SELECT r.result_status, r.account_id, r.request_id
      FROM public.submit_metra_registration(
        p_auth_user_id, p_first_name, p_father_name, p_last_name, p_phone,
        p_role_code, p_station_id, p_terms_version, p_submitted_at, p_idempotency_key
      ) AS r;
END;
$function$;

REVOKE ALL ON FUNCTION public.submit_metra_registration_for_active_station(
  uuid, text, text, text, text, text, uuid, text, timestamp with time zone, text
) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.submit_metra_registration_for_active_station(
  uuid, text, text, text, text, text, uuid, text, timestamp with time zone, text
) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.submit_metra_registration_for_active_station(
  uuid, text, text, text, text, text, uuid, text, timestamp with time zone, text
) TO service_role;

-- Own-account status is returned by the API only after deriving p_user_id from JWT sub.
CREATE OR REPLACE FUNCTION public.get_metra_registration_status(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE
  v_result jsonb;
BEGIN
  IF p_user_id IS NULL OR p_user_id = '00000000-0000-0000-0000-000000000000'::uuid THEN
    RAISE EXCEPTION 'registration_status_user_missing' USING ERRCODE = '22023';
  END IF;

  SELECT jsonb_build_object(
    'account_state', s.account_state,
    'state_reason', s.state_reason,
    'request_id', r.id,
    'request_status', r.status,
    'submitted_at', r.submitted_at,
    'review_note', r.review_note
  )
  INTO v_result
  FROM public.metra_account_states AS s
  LEFT JOIN LATERAL (
    SELECT rr.id, rr.status, rr.submitted_at, rr.review_note
      FROM public.registration_requests AS rr
     WHERE rr.user_id = p_user_id
     ORDER BY rr.submitted_at DESC, rr.id DESC
     LIMIT 1
  ) AS r ON true
  WHERE s.user_id = p_user_id;

  RETURN COALESCE(v_result, jsonb_build_object(
    'account_state', NULL,
    'state_reason', NULL,
    'request_id', NULL,
    'request_status', NULL,
    'submitted_at', NULL,
    'review_note', NULL
  ));
END;
$function$;

REVOKE ALL ON FUNCTION public.get_metra_registration_status(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_metra_registration_status(uuid) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_metra_registration_status(uuid) TO service_role;
