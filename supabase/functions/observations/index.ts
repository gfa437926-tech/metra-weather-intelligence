import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { isValidObservationPayload, isValidObservedAt } from "./validation.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status, headers: { ...corsHeaders, "Content-Type": "application/json; charset=utf-8" },
});
const isObject = (value: unknown): value is Record<string, unknown> =>
  value !== null && typeof value === "object" && !Array.isArray(value);



Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const token = (request.headers.get("Authorization") ?? "").replace(/^Bearer\\s+/i, "");
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
  const userId = authData.user.id;
  const admin = createClient(url, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: account, error: accountError } = await admin
    .from("metra_account_states").select("account_state")
    .eq("user_id", userId).maybeSingle();
  if (accountError) return json({ error: "account_check_failed" }, 500);
  if (account?.account_state !== "active") return json({ error: "account_not_active" }, 403);

  const payload = await request.json().catch(() => ({}));
  if (!isObject(payload) || typeof payload.action !== "string") {
    return json({ error: "invalid_payload" }, 400);
  }
  const action = payload.action;
  const now = new Date().toISOString();

  const { data: assignments, error: assignmentError } = await admin
    .from("station_assignments").select("station_id")
    .eq("user_id", userId).eq("approval_status", "approved")
    .lte("valid_from", now).or("valid_to.is.null,valid_to.gt." + now);
  if (assignmentError) return json({ error: "station_assignment_check_failed" }, 500);
  const assignedIds = [...new Set((assignments ?? []).map((item) => String(item.station_id)))];

  const { data: stationRows, error: stationError } = assignedIds.length
    ? await admin.from("station_catalogue")
      .select("id,local_station_code,name_ar,name_en,station_type")
      .in("id", assignedIds).eq("approval_status", "approved")
      .eq("operational_status", "active").eq("is_demo", false)
    : { data: [], error: null };
  if (stationError) return json({ error: "station_lookup_failed" }, 500);

  const stationMap = new Map((stationRows ?? []).map((station) => [String(station.id), station]));
  const createStationIds: string[] = [];
  const approveStationIds: string[] = [];
  const returnStationIds: string[] = [];
  const reviewStationIds: string[] = [];
  for (const stationId of stationMap.keys()) {
    const checks = await Promise.all([
      admin.rpc("metra_user_has_station_permission", {
        p_user_id: userId, p_station_id: stationId, p_permission_code: "observation.create",
      }),
      admin.rpc("metra_user_has_station_permission", {
        p_user_id: userId, p_station_id: stationId, p_permission_code: "observation.approve",
      }),
      admin.rpc("metra_user_has_station_permission", {
        p_user_id: userId, p_station_id: stationId, p_permission_code: "observation.return_for_correction",
      }),
    ]);
    if (checks.some((result) => result.error)) return json({ error: "station_permission_check_failed" }, 500);
    if (checks[0].data === true) createStationIds.push(stationId);
    if (checks[1].data === true) approveStationIds.push(stationId);
    if (checks[2].data === true) returnStationIds.push(stationId);
    if (checks[1].data === true || checks[2].data === true) reviewStationIds.push(stationId);
  }

  if (action === "catalog") {
    return json({ stations: createStationIds.map((id) => stationMap.get(id)) });
  }

  if (action === "list") {
    const [ownResult, reviewResult] = await Promise.all([
      admin.from("metra_observations")
        .select("id,station_id,created_by,observation_type,observed_at,payload,status,submitted_at,reviewed_at,review_note")
        .eq("created_by", userId).order("created_at", { ascending: false }).limit(100),
      reviewStationIds.length
        ? admin.from("metra_observations")
          .select("id,station_id,created_by,observation_type,observed_at,payload,status,submitted_at,reviewed_at,review_note")
          .in("station_id", reviewStationIds).eq("status", "submitted")
          .neq("created_by", userId).order("submitted_at", { ascending: true }).limit(200)
        : Promise.resolve({ data: [], error: null }),
    ]);
    if (ownResult.error || reviewResult.error) return json({ error: "observation_list_failed" }, 500);
    const stationDetails = (id: string) => {
      const station = stationMap.get(id);
      return station ? { id, code: station.local_station_code, name: station.name_ar } : { id, code: "", name: "محطة" };
    };
    return json({
      own: (ownResult.data ?? []).map((item) => ({ ...item, station: stationDetails(String(item.station_id)) })),
      review: (reviewResult.data ?? []).map((item) => ({
        ...item,
        station: stationDetails(String(item.station_id)),
        can_approve: approveStationIds.includes(String(item.station_id)),
        can_return: returnStationIds.includes(String(item.station_id)),
      })),
      stations: createStationIds.map((id) => stationMap.get(id)),
    });
  }

  if (action === "submit") {
    const stationId = typeof payload.station_id === "string" ? payload.station_id : "";
    const type = typeof payload.observation_type === "string" ? payload.observation_type : "";
    const observedAt = typeof payload.observed_at === "string" ? payload.observed_at : "";
    const idempotencyKey = typeof payload.idempotency_key === "string" ? payload.idempotency_key : "";
    const observationPayload = payload.payload;
    const submit = payload.submit === true;
    if (!stationId || !createStationIds.includes(stationId) ||
        !["daily", "hourly", "phenomenon"].includes(type) ||
        !Number.isFinite(observedTimestamp) || observedTimestamp > Date.now() + 5 * 60 * 1000 ||
        !idempotencyKey.trim() || idempotencyKey.length > 128 ||
        !isObject(observationPayload) || !isValidObservationPayload(type, observationPayload) ||
        new TextEncoder().encode(JSON.stringify(observationPayload)).length > 65536) {
      return json({ error: "invalid_observation_payload" }, 400);
    }
    const { data, error } = await admin.rpc("metra_submit_observation", {
      p_user_id: userId,
      p_station_id: stationId,
      p_idempotency_key: idempotencyKey,
      p_observation_type: type,
      p_observed_at: observedAt,
      p_payload: observationPayload,
      p_submit: submit,
    });
    if (error) {
      if (error.code === "42501") return json({ error: "observation_permission_denied" }, 403);
      return json({ error: "observation_submit_failed" }, 400);
    }
    return json({ result: data ?? null });
  }

  if (action === "decide") {
    const stationId = typeof payload.station_id === "string" ? payload.station_id : "";
    const observationId = typeof payload.observation_id === "string" ? payload.observation_id : "";
    const decision = typeof payload.decision === "string" ? payload.decision : "";
    const note = typeof payload.note === "string" ? payload.note.trim() : "";
    if (!stationId || !reviewStationIds.includes(stationId) || !observationId ||
        !["approve", "return_for_correction"].includes(decision) ||
        note.length > 2000 || (decision === "return_for_correction" && !note)) {
      return json({ error: "invalid_observation_decision" }, 400);
    }
    const { data, error } = await admin.rpc("metra_decide_observation", {
      p_user_id: userId,
      p_station_id: stationId,
      p_observation_id: observationId,
      p_decision: decision,
      p_note: note || null,
    });
    if (error) {
      if (error.code === "42501") return json({ error: "observation_permission_denied" }, 403);
      return json({ error: "observation_decision_failed" }, 400);
    }
    return json({ result: data ?? null });
  }

  return json({ error: "unsupported_action" }, 400);
});
