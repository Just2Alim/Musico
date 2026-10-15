import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return Response.json({ error: "Method not allowed" }, { status: 405, headers: corsHeaders });
  }
  const contentLength = Number(request.headers.get("content-length") ?? 0);
  if (contentLength > 4096) {
    return Response.json({ error: "Request too large" }, { status: 413, headers: corsHeaders });
  }

  const authorization = request.headers.get("Authorization") ?? "";
  if (!authorization.startsWith("Bearer ")) {
    return Response.json({ error: "Authentication required" }, { status: 401, headers: corsHeaders });
  }

  const url = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !anonKey || !serviceRoleKey) {
    return Response.json({ error: "Server is not configured" }, { status: 503, headers: corsHeaders });
  }

  const userClient = createClient(url, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: { user }, error: authError } = await userClient.auth.getUser();
  if (authError || !user) {
    return Response.json({ error: "Invalid session" }, { status: 401, headers: corsHeaders });
  }

  let rawInput: unknown;
  try {
    rawInput = await request.json();
  } catch {
    return Response.json({ error: "Invalid JSON" }, { status: 400, headers: corsHeaders });
  }
  if (typeof rawInput !== "object" || rawInput === null || Array.isArray(rawInput)) {
    return Response.json({ error: "Expected a JSON object" }, { status: 400, headers: corsHeaders });
  }
  const input = rawInput as Record<string, unknown>;
  const platforms = new Set(["android", "ios", "linux", "macos", "windows", "web"]);
  const platform = typeof input.platform === "string" && platforms.has(input.platform.toLowerCase())
    ? input.platform.toLowerCase()
    : "web";
  const errorType = typeof input.error_type === "string"
    ? input.error_type.replace(/[^A-Za-z0-9_.-]/g, "").slice(0, 160) || "UnhandledError"
    : "UnhandledError";

  const admin = createClient(url, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const since = new Date(Date.now() - 60 * 60 * 1000).toISOString();
  const { data: recentReports, error: limitError } = await admin
    .from("app_crash_reports")
    .select("id")
    .eq("user_id", user.id)
    .gte("created_at", since)
    .limit(5);
  if (limitError) {
    return Response.json({ error: "Could not validate report rate" }, { status: 503, headers: corsHeaders });
  }
  if ((recentReports?.length ?? 0) >= 5) {
    return Response.json({ error: "Report limit reached" }, { status: 429, headers: corsHeaders });
  }
  const { error } = await admin.from("app_crash_reports").insert({
    user_id: user.id,
    app_version: "1.0.0",
    platform,
    error_type: errorType,
    message: "Unhandled application error",
  });
  if (error) {
    return Response.json({ error: "Could not save report" }, { status: 500, headers: corsHeaders });
  }
  return Response.json({ accepted: true }, { status: 202, headers: corsHeaders });
});
