import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { isValidRegistrationDecisionResult } from "./validation.ts";
import { chunkValues } from "./batching.ts";

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
    if (!canReviewStation && !canReviewSystem) return json({ error: "permission_denied" }, 403);
    const requestRows: Record<string, unknown>[] = [];
    if (canReviewStation) {
      const { data: assignments, error } = await admin
        .from("station_assignments").select("station_id")
        .eq("user_id", actorId).eq("approval_status", "approved")
        .lte("valid_from", now).or("valid_to.is.null,valid_to.gt." + now);
      if (error) return json({ error: "station_assignment_check_failed" }, 500);
      const assignedIds = [...new Set((assignments ?? []).map((item) => String(item.station_id)))];
      if (assignedIds.length > 0) {
        const eligibleStations: { id: string }[] = [];
        for (const batch of chunkValues(assignedIds, 200)) {
          const { data, error: eligibleError } = await admin
            .from("station_catalogue").select("id")
            .in("id", batch).eq("approval_status", "approved")
            .eq("operational_status", "active").eq("is_demo", false);
          if (eligibleError) return json({ error: "station_eligibility_check_failed" }, 500);
          eligibleStations.push(...(data ?? []));
        }
        const stationIds = eligibleStations.map((item) => String(item.id));
        for (const stationBatch of chunkValues(stationIds, 200)) {
          const pageSize = 500;
          for (let offset = 0; ; offset += pageSize) {
            const { data, error: queueError } = await admin
              .from("registration_requests")
              .select("id,user_id,requested_station_id,requested_role_code,status,submitted_at,terms_version")
              .eq("status", "pending_station_approval")
              .neq("user_id", actorId).in("requested_station_id", stationBatch)
              .order("submitted_at", { ascending: true }).order("id", { ascending: true })
              .range(offset, offset + pageSize - 1);
            if (queueError) return json({ error: "station_queue_failed" }, 500);
            requestRows.push(...(data ?? []));
            if (!data || data.length < pageSize) break;
          }
        }
      }
    }

    if (canReviewSystem) {
      const pending: Record<string, unknown>[] = [];
      const pageSize = 500;
      for (let offset = 0; ; offset += pageSize) {
        const { data, error: pendingError } = await admin
          .from("registration_requests")
          .select("id,user_id,requested_station_id,requested_role_code,status,submitted_at,terms_version")
          .eq("status", "pending_system_approval")
          .neq("user_id", actorId)
          .order("submitted_at", { ascending: true }).order("id", { ascending: true })
          .range(offset, offset + pageSize - 1);
        if (pendingError) return json({ error: "system_queue_failed" }, 500);
        pending.push(...(data ?? []));
        if (!data || data.length < pageSize) break;
      }
      const pendingStationIds = [...new Set(pending.map((item) => String(item.requested_station_id)))];
      let eligibleStationIds = new Set<string>();
      if (pendingStationIds.length > 0) {
        for (const batch of chunkValues(pendingStationIds, 200)) {
          const { data: eligibleStations, error: eligibleError } = await admin
            .from("station_catalogue").select("id")
            .in("id", batch).eq("approval_status", "approved")
            .eq("operational_status", "active").eq("is_demo", false);
          if (eligibleError) return json({ error: "station_eligibility_check_failed" }, 500);
          for (const station of eligibleStations ?? []) eligibleStationIds.add(String(station.id));
        }
      }
      const eligiblePending = pending.filter((item) =>
        eligibleStationIds.has(String(item.requested_station_id)));
      const ids = eligiblePending.map((item) => String(item.id));
      if (ids.length > 0) {
        const distinct = new Set<string>();
        for (const batch of chunkValues(ids, 200)) {
          const { data: approvals, error: auditError } = await admin
            .from("registration_audit_events").select("request_id,actor_user_id")
            .eq("event_type", "station_approved").in("request_id", batch);
          if (auditError) return json({ error: "approval_audit_check_failed" }, 500);
          for (const item of approvals ?? []) {
            if (String(item.actor_user_id) !== actorId) distinct.add(String(item.request_id));
          }
        }
        requestRows.push(...eligiblePending.filter((item) => distinct.has(String(item.id))));
      }
    }

    const userIds = [...new Set(requestRows.map((item) => String(item.user_id)))];
    const stationIds = [...new Set(requestRows.map((item) => String(item.requested_station_id)))];
    const roleCodes = [...new Set(requestRows.map((item) => String(item.requested_role_code)))];
    const profileMap = new Map<string, Record<string, unknown>>();
    const stationMap = new Map<string, Record<string, unknown>>();
    const roleMap = new Map<string, Record<string, unknown>>();
    for (const batch of chunkValues(userIds, 200)) {
      const { data: profiles, error: profileError } = await admin
        .from("metra_user_profiles")
        .select("user_id,first_name,father_name,last_name,phone")
        .in("user_id", batch);
      if (profileError) return json({ error: "queue_details_failed" }, 500);
      for (const profile of profiles ?? []) profileMap.set(String(profile.user_id), profile);
    }
    for (const batch of chunkValues(stationIds, 200)) {
      const { data: stations, error: stationError } = await admin
        .from("station_catalogue")
        .select("id,local_station_code,name_ar,name_en,station_type,approval_status")
        .in("id", batch);
      if (stationError) return json({ error: "queue_details_failed" }, 500);
      for (const station of stations ?? []) stationMap.set(String(station.id), station);
    }
    for (const batch of chunkValues(roleCodes, 200)) {
      const { data: roles, error: roleError } = await admin
        .from("metra_role_catalogue")
        .select("role_code,name_ar,name_en,is_active")
        .in("role_code", batch);
      if (roleError) return json({ error: "queue_details_failed" }, 500);
      for (const role of roles ?? []) roleMap.set(String(role.role_code), role);
    }
    const items = requestRows.map((item) => ({
      ...item,
      applicant: profileMap.get(String(item.user_id)) ?? null,
      station: stationMap.get(String(item.requested_station_id)) ?? null,
      requested_role: roleMap.get(String(item.requested_role_code)) ?? null,
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
    const { data, error } = await admin.rpc("decide_metra_registration", {
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
    if (!isValidRegistrationDecisionResult(result, expectedStatus, decision)) {
      if (result && typeof result === "object" && !Array.isArray(result)) {
        const resultStatus = String((result as Record<string, unknown>).result_status ?? "");
        if (resultStatus === "unauthorized") return json({ error: "permission_denied" }, 403);
        if (resultStatus === "not_found") return json({ error: "registration_request_not_found" }, 404);
        if (resultStatus === "conflict") return json({ error: "registration_state_conflict", result }, 409);
      }
      return json({ error: "registration_decision_unconfirmed" }, 502);
    }
    return json({ result });
  }

  if (!canReviewStation && !canReviewSystem) return json({ error: "permission_denied" }, 403);
  return json({ error: "unsupported_action" }, 400);
});
