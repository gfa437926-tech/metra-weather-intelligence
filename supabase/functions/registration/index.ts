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

  const token = (request.headers.get("Authorization") ?? "").replace(/^Bearer\\s+/i, "");
  if (!token) return json({ error: "unauthorized" }, 401);
  const url = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !anonKey || !serviceKey) return json({ error: "server_configuration_error" }, 500);

  const authClient = createClient(url, anonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { Authorization: "Bearer " + token } },
  });
  const { data: authData, error: authError } = await authClient.auth.getUser(token);
  if (authError || !authData.user) return json({ error: "unauthorized" }, 401);
  const userId = authData.user.id;
  const admin = createClient(url, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const payload = await request.json().catch(() => ({}));
  const action = payload && typeof payload.action === "string" ? payload.action : "";

  if (action === "status") {
    const { data: account, error: accountError } = await admin
      .from("metra_account_states").select("account_state,state_reason")
      .eq("user_id", userId).maybeSingle();
    if (accountError) return json({ error: "account_status_failed" }, 500);
    const { data: registration, error: registrationError } = await admin
      .from("registration_requests")
      .select("status,review_note,submitted_at,requested_role_code")
      .eq("user_id", userId).order("submitted_at", { ascending: false }).limit(1).maybeSingle();
    if (registrationError) return json({ error: "registration_status_failed" }, 500);
    return json({
      account_state: account?.account_state ?? "needs_registration",
      state_reason: account?.state_reason ?? null,
      registration: registration ?? null,
    });
  }

  if (action === "catalog") {
    const [{ data: roles, error: rolesError }, { data: authorities, error: authoritiesError }] =
      await Promise.all([
        admin.from("metra_role_catalogue")
          .select("role_code,name_ar,description_ar,display_order")
          .eq("is_active", true).eq("is_requestable", true)
          .order("display_order", { ascending: true }),
        admin.from("meteorological_authorities")
          .select("id,name_ar").eq("is_active", true),
      ]);
    if (rolesError || authoritiesError) return json({ error: "registration_catalog_failed" }, 500);
    const authorityNames = new Map((authorities ?? []).map((item) => [String(item.id), String(item.name_ar)]));
    const { data: stations, error: stationError } = await admin
      .from("station_catalogue")
      .select("id,local_station_code,name_ar,name_en,station_type,operational_status,approval_status,owner_authority_id")
      .eq("is_demo", false).order("name_ar", { ascending: true });
    if (stationError) return json({ error: "station_catalog_failed" }, 500);
    const availableStations = (stations ?? [])
      .filter((station) => authorityNames.has(String(station.owner_authority_id)))
      .map((station) => ({
        id: station.id,
        code: station.local_station_code,
        name_ar: station.name_ar,
        name_en: station.name_en,
        station_type: station.station_type,
        operational_status: station.operational_status,
        approval_status: station.approval_status,
        authority_name: authorityNames.get(String(station.owner_authority_id)),
      }));
    return json({ roles: roles ?? [], stations: availableStations });
  }

  if (action === "submit") {
    const required = ["first_name", "father_name", "last_name", "role_code", "station_id", "terms_version", "idempotency_key"];
    if (!payload || required.some((key) => typeof payload[key] !== "string" || !payload[key].trim())) {
      return json({ error: "invalid_registration_payload" }, 400);
    }
    const { data, error } = await authClient.rpc("submit_metra_registration", {
      p_auth_user_id: userId,
      p_first_name: payload.first_name.trim(),
      p_father_name: payload.father_name.trim(),
      p_last_name: payload.last_name.trim(),
      p_phone: typeof payload.phone === "string" ? payload.phone.trim() : null,
      p_role_code: payload.role_code.trim(),
      p_station_id: payload.station_id,
      p_terms_version: payload.terms_version.trim(),
      p_submitted_at: new Date().toISOString(),
      p_idempotency_key: payload.idempotency_key.trim(),
    });
    if (error) {
      if (error.code === "42501") return json({ error: "registration_not_authorized" }, 403);
      return json({ error: "registration_submission_failed", message: error.message }, 400);
    }
    const result = Array.isArray(data) ? data[0] : data;
    return json({ result: result ?? null });
  }

  return json({ error: "unsupported_action" }, 400);
});
