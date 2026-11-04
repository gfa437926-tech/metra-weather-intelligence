-- Allow an authorized, different station manager to revoke an active assignment.
CREATE OR REPLACE FUNCTION public.revoke_station_assignment(
  p_assignment_id uuid,
  p_station_id uuid,
  p_actor_user_id uuid,
  p_reason text,
  p_occurred_at timestamp with time zone
)
RETURNS TABLE(result_status text, resulting_status text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public', 'private'
AS $function$
DECLARE
  v_assignment public.station_assignments%rowtype;
  v_now timestamptz := clock_timestamp();
BEGIN
  IF p_assignment_id IS NULL OR p_station_id IS NULL OR p_actor_user_id IS NULL
     OR p_reason IS NULL OR length(trim(p_reason)) NOT BETWEEN 5 AND 2000
     OR p_reason <> trim(p_reason) OR p_reason ~ '[[:cntrl:]]'
     OR p_occurred_at IS NULL THEN
    RAISE EXCEPTION 'invalid_station_assignment_revocation' USING ERRCODE = '22023';
  END IF;

  SELECT a.* INTO v_assignment
    FROM public.station_assignments AS a
   WHERE a.id = p_assignment_id AND a.station_id = p_station_id
   FOR UPDATE;
  IF NOT FOUND THEN
    RETURN QUERY SELECT 'not_found'::text, NULL::text;
    RETURN;
  END IF;

  IF v_assignment.approval_status <> 'approved' THEN
    RETURN QUERY SELECT 'conflict'::text, v_assignment.approval_status;
    RETURN;
  END IF;

  IF v_assignment.user_id = p_actor_user_id THEN
    RETURN QUERY SELECT 'unauthorized'::text, v_assignment.approval_status;
    RETURN;
  END IF;

  IF public.metra_user_has_station_permission(
    p_actor_user_id, p_station_id, 'users.station.manage'
  ) IS DISTINCT FROM true THEN
    RETURN QUERY SELECT 'unauthorized'::text, v_assignment.approval_status;
    RETURN;
  END IF;

  UPDATE public.station_assignments
     SET approval_status = 'revoked',
         updated_at = v_now
   WHERE id = p_assignment_id;

  INSERT INTO public.station_audit_log(
    entity_type, entity_id, action, actor_id, reason, before_data, after_data, occurred_at
  ) VALUES (
    'station_assignment', p_assignment_id, 'assignment_revoked',
    p_actor_user_id, trim(p_reason), to_jsonb(v_assignment),
    jsonb_build_object(
      'id', p_assignment_id,
      'user_id', v_assignment.user_id,
      'station_id', v_assignment.station_id,
      'authority_id', v_assignment.authority_id,
      'role_code', v_assignment.assignment_role_code,
      'approval_status', 'revoked'
    ), v_now
  );

  RETURN QUERY SELECT 'committed'::text, 'revoked'::text;
END;
$function$;

REVOKE ALL ON FUNCTION public.revoke_station_assignment(uuid, uuid, uuid, text, timestamp with time zone) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.revoke_station_assignment(uuid, uuid, uuid, text, timestamp with time zone) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.revoke_station_assignment(uuid, uuid, uuid, text, timestamp with time zone) TO service_role;
