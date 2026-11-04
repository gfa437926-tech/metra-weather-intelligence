import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status, headers: { ...corsHeaders, "Content-Type": "application/json; charset=utf-8" },
});

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const token = (request.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  if (!token) return json({ error: "unauthorized" }, 401);
  const url = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !anonKey || !serviceKey) return json({ error: "server_configuration_error" }, 500);

  const userClient = createClient(url, anonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { Authorization: "Bearer " + token } },
  });
  const { data: authData, error: authError } = await userClient.auth.getUser(token);
  if (authError || !authData.user) return json({ error: "unauthorized" }, 401);
  const actorId = authData.user.id;
  const admin = createClient(url, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const now = new Date().toISOString();
  const { data: account, error: accountError } = await admin
    .from("metra_account_states").select("account_state")
    .eq("user_id", actorId).maybeSingle();
  if (accountError) return json({ error: "account_check_failed" }, 500);
  if (account?.account_state !== "active") return json({ error: "account_not_active" }, 403);

  const { data: grants, error: grantsError } = await admin
    .from("permission_grants").select("permission_code")
    .eq("user_id", actorId).eq("approval_status", "approved")
    .is("revoked_at", null).lte("valid_from", now)
    .or("valid_to.is.null,valid_to.gt." + now);
  if (grantsError) return json({ error: "permission_check_failed" }, 500);
  const permissions = new Set((grants ?? []).map((item) => String(item.permission_code)));
  const canReviewStation = permissions.has("registrations.station.approve");
  const canReviewSystem = permissions.has("registrations.system.approve");

  const payload = await request.json().catch(() => ({}));
  const action = payload && typeof payload.action === "string" ? payload.action : "";

  if (action === "queue") {
    const requestRows: Record<string, unknown>[] = [];
    if (canReviewStation) {
      const { data: assignments, error } = await admin
        .from("station_assignments").select("station_id")
        .eq("user_id", actorId).eq("approval_status", "approved")
        .lte("valid_from", now).or("valid_to.is.null,valid_to.gt." + now);
      if (error) return json({ error: "station_assignment_check_failed" }, 500);
      const stationIds = [...new Set((assignments ?? []).map((item) => String(item.station_id)))];
      if (stationIds.length > 0) {
        const { data, error: queueError } = await admin
          .from("registration_requests")
          .select("id,user_id,requested_station_id,requested_role_code,status,submitted_at,terms_version")
          .eq("status", "pending_station_approval")
          .neq("user_id", actorId).in("requested_station_id", stationIds)
          .order("submitted_at", { ascending: true });
        if (queueError) return json({ error: "station_queue_failed" }, 500);
        requestRows.push(...(data ?? []));
      }
    }

    if (canReviewSystem) {
      const { data: pending, error: pendingError } = await admin
        .from("registration_requests")
        .select("id,user_id,requested_station_id,requested_role_code,status,submitted_at,terms_version")
        .eq("status", "pending_system_approval")
        .neq("user_id", actorId)
        .order("submitted_at", { ascending: true });
      if (pendingError) return json({ error: "system_queue_failed" }, 500);
      const ids = (pending ?? []).map((item) => String(item.id));
      if (ids.length > 0) {
        const { data: approvals, error: auditError } = await admin
          .from("registration_audit_events").select("request_id,actor_user_id")
          .eq("event_type", "station_approved").in("request_id", ids);
        if (auditError) return json({ error: "approval_audit_check_failed" }, 500);
        const distinct = new Set((approvals ?? [])
          .filter((item) => String(item.actor_user_id) !== actorId)
          .map((item) => String(item.request_id)));
        requestRows.push(...(pending ?? []).filter((item) => distinct.has(String(item.id))));
      }
    }

    const userIds = [...new Set(requestRows.map((item) => String(item.user_id)))];
    const stationIds = [...new Set(requestRows.map((item) => String(item.requested_station_id)))];
    const [{ data: profiles, error: profileError }, { data: stations, error: stationError }] =
      await Promise.all([
        userIds.length ? admin.from("metra_user_profiles")
          .select("user_id,first_name,father_name,last_name,phone")
          .in("user_id", userIds) : Promise.resolve({ data: [], error: null }),
        stationIds.length ? admin.from("station_catalogue")
          .select("id,local_station_code,name_ar,name_en,station_type,approval_status")
          .in("id", stationIds) : Promise.resolve({ data: [], error: null }),
      ]);
    if (profileError || stationError) return json({ error: "queue_details_failed" }, 500);
    const profileMap = new Map((profiles ?? []).map((item) => [String(item.user_id), item]));
    const stationMap = new Map((stations ?? []).map((item) => [String(item.id), item]));
    const items = requestRows.map((item) => ({
      ...item,
      applicant: profileMap.get(String(item.user_id)) ?? null,
      station: stationMap.get(String(item.requested_station_id)) ?? null,
      review_stage: item.status === "pending_station_approval" ? "station" : "system",
    }));
    return json({ items, permissions: [...permissions].filter((p) => p.startsWith("registrations.")) });
  }

  if (action === "decide") {
    const requestId = typeof payload.request_id === "string" ? payload.request_id : "";
    const expectedStatus = typeof payload.expected_status === "string" ? payload.expected_status : "";
    const decision = typeof payload.decision === "string" ? payload.decision : "";
    const note = typeof payload.note === "string" ? payload.note.trim() : "";
    if (!requestId || !["pending_station_approval", "pending_system_approval"].includes(expectedStatus) ||
        !["approve", "reject"].includes(decision) || note.length > 2000 ||
        (decision === "reject" && !note)) {
      return json({ error: "invalid_decision_payload" }, 400);
    }
    const { data, error } = await userClient.rpc("decide_metra_registration", {
      p_request_id: requestId,
      p_expected_status: expectedStatus,
      p_actor_user_id: actorId,
      p_decision: decision,
      p_note: note || null,
      p_occurred_at: now,
    });
    if (error) {
      if (error.code === "42501") return json({ error: "permission_denied" }, 403);
      return json({ error: "decision_failed", message: error.message }, 400);
    }
    const result = Array.isArray(data) ? data[0] : data;
    return json({ result: result ?? null });
  }

  if (!canReviewStation && !canReviewSystem) return json({ error: "permission_denied" }, 403);
  return json({ error: "unsupported_action" }, 400);
});
