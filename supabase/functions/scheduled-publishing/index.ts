// Bharat Tech Pulse — scheduled publishing trigger (Deno edge function).
// Called server-to-server by Supabase cron/invoke. Secrets come ONLY from
// Supabase server-side env vars; nothing is hardcoded.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async (req: Request) => {
  // Server-to-server: POST only; answer CORS preflight gracefully.
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: { "Access-Control-Allow-Origin": "*" } });
  }
  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405 });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    return new Response("Server misconfiguration", { status: 500 });
  }

  // Service role can EXECUTE the function (revoked from public in 005).
  const supabase = createClient(supabaseUrl, serviceRoleKey);
  const { data, error } = await supabase.rpc("publish_scheduled_posts");

  if (error) {
    return Response.json({ error: error.message }, { status: 500 });
  }
  return Response.json({ published: data ?? 0 });
});
