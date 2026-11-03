import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status, headers: { ...corsHeaders, "Content-Type": "application/json; charset=utf-8" },
});

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "GET" && request.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  const token = (request.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  if (!token) return json({ error: "unauthorized" }, 401);

  const url = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !anonKey || !serviceKey) return json({ error: "server_configuration_error" }, 500);

  const authClient = createClient(url, anonKey, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data: userData, error: userError } = await authClient.auth.getUser(token);
  if (userError || !userData.user) return json({ error: "unauthorized" }, 401);

  const admin = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data: account, error: accountError } = await admin
    .from("metra_account_states").select("account_state")
    .eq("user_id", userData.user.id).maybeSingle();
  if (accountError) return json({ error: "account_check_failed" }, 500);
  if (account?.account_state !== "active") {
    return json({ error: "account_not_active", state: account?.account_state ?? "pending" }, 403);
  }

  // Fetch in pages so the directory is not silently truncated at 1,000 records.
  const stations: Record<string, unknown>[] = [];
  const pageSize = 1000;
  for (let offset = 0; ; offset += pageSize) {
    const { data: page, error: stationError } = await admin
      .from("station_catalogue")
      .select("id,local_station_code,name_ar,name_en,station_type,operational_status,approval_status,is_demo")
      .eq("is_demo", false).order("name_ar", { ascending: true })
      .range(offset, offset + pageSize - 1);
    if (stationError) return json({ error: "station_query_failed" }, 500);
    stations.push(...(page ?? []));
    if (!page || page.length < pageSize) break;
  }

  const ids = stations.map((station) => String(station.id));
  const coordinateMap = new Map<string, { latitude: number; longitude: number }>();
  // PostgREST URL limits vary; keep each station-coordinate lookup bounded.
  for ( (let offset = 0; offset < ids.length; offset += 200) {
    const batch = ids.slice(offset, offset + 200);
    const { data: coordinates, error: coordinateError } = await admin
      .from("station_coordinates")
      .select("station_id,latitude,longitude,valid_from")
      .in("station_id", batch).is("valid_to", null)
      .order("valid_from", { ascending: false });
    if (coordinateError) return json({ error: "coordinate_query_failed" }, 500);
    for (const item of coordinates ?? []) {
      if (!coordinateMap.has(String(item.station_id))) coordinateMap.set(String(item.station_id), {
        latitude: Number(item.latitude), longitude: Number(item.longitude),
      });
    }
  }

  const result = stations.map((station) => ({
    ...station, ...(coordinateMap.get(String(station.id)) ?? { latitude: null, longitude: null }),
  }));
  return json({
    stations: result,
    total: result.length,
    with_coordinates: result.filter((station) => station.latitude !== null).length,
    generated_at: new Date().toISOString(),
  });
});
