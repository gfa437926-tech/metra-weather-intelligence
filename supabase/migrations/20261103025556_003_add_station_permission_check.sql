-- METRA 2027: fail-closed station-scoped authorization predicate.
-- Apply to the NEW METRA project only. Does not touch the legacy INSERT database.

CREATE OR REPLACE FUNCTION public.metra_user_has_station_permission(
    p_user_id uuid,
    p_station_id uuid,
    p_permission_code text
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $function$
    SELECT COALESCE(EXISTS (
        SELECT 1
        FROM public.metra_account_states AS account
        JOIN public.station_catalogue AS station
          ON station.id = p_station_id
        JOIN public.meteorological_authorities AS authority
          ON authority.id = station.owner_authority_id
         AND authority.country_id = station.country_id
        JOIN public.countries AS country
          ON country.id = station.country_id
        JOIN public.authority_memberships AS membership
          ON membership.user_id = account.user_id
         AND membership.authority_id = station.owner_authority_id
        JOIN public.station_assignments AS assignment
          ON assignment.user_id = account.user_id
         AND assignment.station_id = station.id
         AND assignment.authority_id = station.owner_authority_id
        JOIN public.metra_role_catalogue AS role
          ON role.role_code = assignment.assignment_role_code
         AND role.is_active = TRUE
        -- Individual grants are not sufficient: the permission must also
        -- be explicitly allowed for the assigned role.
        JOIN public.metra_role_permissions AS role_permission
          ON role_permission.role_code = role.role_code
         AND role_permission.permission_code = p_permission_code
        JOIN public.permission_grants AS permission
          ON permission.user_id = account.user_id
         AND permission.permission_code = p_permission_code
        WHERE account.user_id = p_user_id
          AND account.account_state = 'active'
          AND station.approval_status = 'approved'
          AND station.operational_status = 'active'
          AND station.is_demo = FALSE
          AND authority.is_active = TRUE
          AND country.is_active = TRUE
          AND membership.approval_status = 'approved'
          AND membership.valid_from <= now()
          AND (membership.valid_to IS NULL OR membership.valid_to > now())
          AND assignment.approval_status = 'approved'
          AND assignment.valid_from <= now()
          AND (assignment.valid_to IS NULL OR assignment.valid_to > now())
          AND permission.approval_status = 'approved'
          AND permission.revoked_at IS NULL
          AND permission.valid_from <= now()
          AND (permission.valid_to IS NULL OR permission.valid_to > now())
    ), FALSE);
$function$;

REVOKE ALL ON FUNCTION public.metra_user_has_station_permission(uuid, uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.metra_user_has_station_permission(uuid, uuid, text) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.metra_user_has_station_permission(uuid, uuid, text) TO service_role;
