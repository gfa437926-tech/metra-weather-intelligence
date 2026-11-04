-- Bind registration decisions to the station in the route.
-- The request row is locked before its station is compared; the existing
-- transactional decision function then reuses that lock and performs the
-- stage, self-review, account, grant, assignment and audit checks.
CREATE OR REPLACE FUNCTION public.decide_metra_registration_for_station(
  p_request_id uuid,
  p_station_id uuid,
  p_expected_status text,
  p_actor_user_id uuid,
  p_decision text,
  p_note text,
  p_occurred_at timestamp with time zone
)
RETURNS TABLE(result_status text, resulting_status text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public', 'private'
AS $function$
DECLARE
  v_requested_station_id uuid;
BEGIN
  IF p_request_id IS NULL OR p_station_id IS NULL THEN
    RAISE EXCEPTION 'registration_request_and_station_required' USING ERRCODE = '22023';
  END IF;

  SELECT r.requested_station_id
    INTO v_requested_station_id
    FROM public.registration_requests AS r
   WHERE r.id = p_request_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RETURN QUERY SELECT 'not_found'::text, NULL::text;
    RETURN;
  END IF;

  IF v_requested_station_id IS DISTINCT FROM p_station_id THEN
    RETURN QUERY SELECT 'unauthorized'::text, NULL::text;
    RETURN;
  END IF;

  RETURN QUERY
    SELECT d.result_status, d.resulting_status
      FROM public.decide_metra_registration(
        p_request_id,
        p_expected_status,
        p_actor_user_id,
        p_decision,
        p_note,
        p_occurred_at
      ) AS d;
END;
$function$;

REVOKE ALL ON FUNCTION public.decide_metra_registration_for_station(
  uuid, uuid, text, uuid, text, text, timestamp with time zone
) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.decide_metra_registration_for_station(
  uuid, uuid, text, uuid, text, text, timestamp with time zone
) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.decide_metra_registration_for_station(
  uuid, uuid, text, uuid, text, text, timestamp with time zone
) TO service_role;
