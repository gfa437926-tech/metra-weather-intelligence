-- Station-scoped assignment workflow. Only observer and station_auditor may
-- be assigned through this station-manager path; management and director roles
-- require a separately reviewed authority-level workflow.
INSERT INTO public.metra_role_permissions (role_code, permission_code)
VALUES
  ('station_head', 'users.station.manage'),
  ('system_admin', 'users.station.manage')
ON CONFLICT (role_code, permission_code) DO NOTHING;

CREATE OR REPLACE FUNCTION public.request_station_assignment(
  p_user_id uuid,
  p_station_id uuid,
  p_role_code text,
  p_actor_user_id uuid,
  p_reason text,
  p_valid_from timestamp with time zone,
  p_valid_to timestamp with time zone
)
RETURNS TABLE(result_status text, assignment_id uuid)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public', 'private'
AS $function$
DECLARE
  v_authority_id uuid;
  v_assignment_id uuid;
  v_now timestamptz := clock_timestamp();
BEGIN
  IF p_user_id IS NULL OR p_station_id IS NULL OR p_actor_user_id IS NULL
     OR p_user_id = p_actor_user_id
     OR p_role_code IS NULL OR p_role_code NOT IN ('observer', 'station_auditor')
     OR p_reason IS NULL OR length(trim(p_reason)) NOT BETWEEN 5 AND 2000
     OR p_reason <> trim(p_reason) OR p_reason ~ '[[:cntrl:]]'
     OR p_valid_from IS NULL
     OR (p_valid_to IS NOT NULL AND p_valid_to <= p_valid_from) THEN
    RAISE EXCEPTION 'invalid_station_assignment_request' USING ERRCODE = '22023';
  END IF;

  IF public.metra_user_has_station_permission(
    p_actor_user_id, p_station_id, 'users.station.manage'
  ) IS DISTINCT FROM true THEN
    RETURN QUERY SELECT 'unauthorized'::text, NULL::uuid;
    RETURN;
  END IF;

  SELECT s.owner_authority_id INTO v_authority_id
    FROM public.station_catalogue AS s
    JOIN public.meteorological_authorities AS authority ON authority.id = s.owner_authority_id
   WHERE s.id = p_station_id
     AND s.approval_status = 'approved'
     AND s.operational_status = 'active'
     AND s.is_demo = false
     AND authority.is_active = true
   FOR SHARE OF s, authority;
  IF v_authority_id IS NULL THEN
    RETURN QUERY SELECT 'station_not_available'::text, NULL::uuid;
    RETURN;
  END IF;

  PERFORM 1 FROM public.metra_account_states AS state
   WHERE state.user_id = p_user_id AND state.account_state = 'active'
   FOR SHARE;
  IF NOT FOUND THEN
    RETURN QUERY SELECT 'target_account_not_active'::text, NULL::uuid;
    RETURN;
  END IF;

  PERFORM 1 FROM public.authority_memberships AS membership
   JOIN public.metra_role_catalogue AS membership_role
     ON membership_role.role_code = membership.membership_role_code
   WHERE membership.user_id = p_user_id
     AND membership.authority_id = v_authority_id
     AND membership.approval_status = 'approved'
     AND membership.valid_from <= v_now
     AND (membership.valid_to IS NULL OR membership.valid_to > v_now)
     AND membership_role.is_active = true
   FOR SHARE OF membership;
  IF NOT FOUND THEN
    RETURN QUERY SELECT 'target_authority_membership_required'::text, NULL::uuid;
    RETURN;
  END IF;

  PERFORM 1 FROM public.metra_role_catalogue AS role
   WHERE role.role_code = p_role_code AND role.is_active = true;
  IF NOT FOUND THEN
    RETURN QUERY SELECT 'assignment_role_unavailable'::text, NULL::uuid;
    RETURN;
  END IF;

  INSERT INTO public.station_assignments(
    user_id, station_id, authority_id, assignment_role_code,
    approval_status, valid_from, valid_to, requested_by, reason
  ) VALUES (
    p_user_id, p_station_id, v_authority_id, p_role_code,
    'pending', p_valid_from, p_valid_to, p_actor_user_id, trim(p_reason)
  ) RETURNING id INTO v_assignment_id;

  INSERT INTO public.station_audit_log(
    entity_type, entity_id, action, actor_id, reason, before_data, after_data, occurred_at
  ) VALUES (
    'station_assignment', v_assignment_id, 'assignment_requested',
    p_actor_user_id, trim(p_reason), NULL,
    jsonb_build_object(
      'user_id', p_user_id, 'station_id', p_station_id,
      'authority_id', v_authority_id, 'role_code', p_role_code,
      'approval_status', 'pending', 'valid_from', p_valid_from, 'valid_to', p_valid_to
    ), v_now
  );

  RETURN QUERY SELECT 'created'::text, v_assignment_id;
EXCEPTION
  WHEN exclusion_violation THEN
    RETURN QUERY SELECT 'conflict'::text, NULL::uuid;
END;
$function$;

CREATE OR REPLACE FUNCTION public.decide_station_assignment(
  p_assignment_id uuid,
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
  v_assignment public.station_assignments%rowtype;
  v_authority_id uuid;
  v_now timestamptz := clock_timestamp();
  v_next_status text;
BEGIN
  IF p_assignment_id IS NULL OR p_station_id IS NULL OR p_actor_user_id IS NULL
     OR p_expected_status IS DISTINCT FROM 'pending'
     OR p_decision IS NULL OR p_decision NOT IN ('approve', 'reject')
     OR p_occurred_at IS NULL
     OR (p_note IS NOT NULL AND length(p_note) > 2000)
     OR (p_note IS NOT NULL AND p_note ~ '[[:cntrl:]]')
     OR (p_decision = 'reject' AND nullif(trim(p_note), '') IS NULL) THEN
    RAISE EXCEPTION 'invalid_station_assignment_decision' USING ERRCODE = '22023';
  END IF;

  SELECT a.* INTO v_assignment
    FROM public.station_assignments AS a
   WHERE a.id = p_assignment_id AND a.station_id = p_station_id
   FOR UPDATE;
  IF NOT FOUND THEN
    RETURN QUERY SELECT 'not_found'::text, NULL::text;
    RETURN;
  END IF;

  IF v_assignment.approval_status <> p_expected_status THEN
    RETURN QUERY SELECT 'conflict'::text, v_assignment.approval_status;
    RETURN;
  END IF;

  IF v_assignment.user_id = p_actor_user_id OR v_assignment.requested_by = p_actor_user_id THEN
    RETURN QUERY SELECT 'unauthorized'::text, v_assignment.approval_status;
    RETURN;
  END IF;

  IF public.metra_user_has_station_permission(
    p_actor_user_id, p_station_id, 'users.station.manage'
  ) IS DISTINCT FROM true THEN
    RETURN QUERY SELECT 'unauthorized'::text, v_assignment.approval_status;
    RETURN;
  END IF;

  SELECT s.owner_authority_id INTO v_authority_id
    FROM public.station_catalogue AS s
    JOIN public.meteorological_authorities AS authority ON authority.id = s.owner_authority_id
   WHERE s.id = p_station_id
     AND s.owner_authority_id = v_assignment.authority_id
     AND s.approval_status = 'approved'
     AND s.operational_status = 'active'
     AND s.is_demo = false
     AND authority.is_active = true
   FOR SHARE OF s, authority;
  IF v_authority_id IS NULL THEN
    RETURN QUERY SELECT 'conflict'::text, v_assignment.approval_status;
    RETURN;
  END IF;

  PERFORM 1 FROM public.metra_account_states AS state
   WHERE state.user_id = v_assignment.user_id AND state.account_state = 'active'
   FOR SHARE;
  IF NOT FOUND THEN
    RETURN QUERY SELECT 'conflict'::text, v_assignment.approval_status;
    RETURN;
  END IF;

  PERFORM 1 FROM public.authority_memberships AS membership
   JOIN public.metra_role_catalogue AS membership_role
     ON membership_role.role_code = membership.membership_role_code
   WHERE membership.user_id = v_assignment.user_id
     AND membership.authority_id = v_authority_id
     AND membership.approval_status = 'approved'
     AND membership.valid_from <= v_now
     AND (membership.valid_to IS NULL OR membership.valid_to > v_now)
     AND membership_role.is_active = true
   FOR SHARE OF membership;
  IF NOT FOUND THEN
    RETURN QUERY SELECT 'conflict'::text, v_assignment.approval_status;
    RETURN;
  END IF;

  PERFORM 1 FROM public.metra_role_catalogue AS role
   WHERE role.role_code = v_assignment.assignment_role_code
     AND role.is_active = true
     AND role.role_code IN ('observer', 'station_auditor')
   FOR SHARE;
  IF NOT FOUND THEN
    RETURN QUERY SELECT 'conflict'::text, v_assignment.approval_status;
    RETURN;
  END IF;

  v_next_status := CASE WHEN p_decision = 'approve' THEN 'approved' ELSE 'rejected' END;
  UPDATE public.station_assignments
     SET approval_status = v_next_status,
         approved_by = p_actor_user_id,
         reviewed_at = v_now,
         updated_at = v_now
   WHERE id = p_assignment_id;

  INSERT INTO public.station_audit_log(
    entity_type, entity_id, action, actor_id, reason, before_data, after_data, occurred_at
  ) VALUES (
    'station_assignment', p_assignment_id,
    CASE WHEN p_decision = 'approve' THEN 'assignment_approved' ELSE 'assignment_rejected' END,
    p_actor_user_id, nullif(trim(p_note), ''),
    to_jsonb(v_assignment),
    jsonb_build_object(
      'id', p_assignment_id, 'user_id', v_assignment.user_id,
      'station_id', v_assignment.station_id, 'authority_id', v_assignment.authority_id,
      'role_code', v_assignment.assignment_role_code,
      'approval_status', v_next_status, 'approved_by', p_actor_user_id, 'reviewed_at', v_now
    ), v_now
  );

  RETURN QUERY SELECT 'committed'::text, v_next_status;
END;
$function$;

REVOKE ALL ON FUNCTION public.request_station_assignment(uuid, uuid, text, uuid, text, timestamp with time zone, timestamp with time zone) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.request_station_assignment(uuid, uuid, text, uuid, text, timestamp with time zone, timestamp with time zone) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.request_station_assignment(uuid, uuid, text, uuid, text, timestamp with time zone, timestamp with time zone) TO service_role;

REVOKE ALL ON FUNCTION public.decide_station_assignment(uuid, uuid, text, uuid, text, text, timestamp with time zone) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.decide_station_assignment(uuid, uuid, text, uuid, text, text, timestamp with time zone) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.decide_station_assignment(uuid, uuid, text, uuid, text, text, timestamp with time zone) TO service_role;
