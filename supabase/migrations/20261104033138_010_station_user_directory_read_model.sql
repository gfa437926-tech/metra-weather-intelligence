-- Read-only station staff directory. It exposes only profile, account-state
-- and assignment fields needed by authorized station/system reviewers.
CREATE OR REPLACE FUNCTION public.get_station_user_directory(
  p_station_id uuid,
  p_limit integer DEFAULT 250
)
RETURNS SETOF jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public'
AS $function$
BEGIN
  IF p_station_id IS NULL OR p_limit IS NULL OR p_limit < 1 OR p_limit > 500 THEN
    RAISE EXCEPTION 'invalid_station_user_directory_query' USING ERRCODE = '22023';
  END IF;

  RETURN QUERY
    SELECT jsonb_build_object(
      'user_id', p.user_id,
      'first_name', p.first_name,
      'father_name', p.father_name,
      'last_name', p.last_name,
      'phone', p.phone,
      'account_state', state.account_state,
      'state_reason', state.state_reason,
      'assignment_id', assignment.id,
      'assignment_role_code', assignment.assignment_role_code,
      'assignment_status', assignment.approval_status,
      'valid_from', assignment.valid_from,
      'valid_to', assignment.valid_to,
      'station_id', assignment.station_id,
      'role_name_ar', role.name_ar,
      'role_name_en', role.name_en
    )
    FROM public.station_assignments AS assignment
    JOIN public.metra_user_profiles AS p ON p.user_id = assignment.user_id
    LEFT JOIN public.metra_account_states AS state ON state.user_id = assignment.user_id
    LEFT JOIN public.metra_role_catalogue AS role ON role.role_code = assignment.assignment_role_code
    WHERE assignment.station_id = p_station_id
    ORDER BY
      CASE assignment.approval_status WHEN 'approved' THEN 0 WHEN 'pending' THEN 1 ELSE 2 END,
      p.last_name, p.first_name, assignment.valid_from DESC
    LIMIT p_limit;
END;
$function$;

REVOKE ALL ON FUNCTION public.get_station_user_directory(uuid, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_station_user_directory(uuid, integer) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_station_user_directory(uuid, integer) TO service_role;
