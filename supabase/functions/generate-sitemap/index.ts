// Bharat Tech Pulse — sitemap generator (Deno edge function).
// Secrets come ONLY from Supabase server-side env vars; nothing is hardcoded.
// Serves GET https://<project>.functions.supabase.co/generate-sitemap
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SITE_URL = "https://bharattechpulse.in";
const SITE_SLUG = "india_tech";

const escapeXml = (s: string): string =>
  s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;").replace(/'/g, "&apos;");

Deno.serve(async (req: Request) => {
  if (req.method !== "GET") {
    return new Response("Method Not Allowed", { status: 405 });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    return new Response("Server misconfiguration", { status: 500 });
  }

  // Service role bypasses RLS; we only ever select published posts.
  const supabase = createClient(supabaseUrl, serviceRoleKey);
  const { data: site, error: siteErr } = await supabase
    .from("sites").select("id").eq("slug", SITE_SLUG).single();
  if (siteErr || !site) {
    return new Response("Site not found", { status: 404 });
  }

  const { data: posts, error } = await supabase
    .from("posts")
    .select("slug,updated_at")
    .eq("site_id", site.id)
    .eq("status", "published")
    .order("published_at", { ascending: false })
    .limit(50000);
  if (error) {
    return new Response(`Query failed: ${error.message}`, { status: 500 });
  }

  const urls = (posts ?? []).map((p: any) => {
    const lastmod = p.updated_at
      ? `<lastmod>${new Date(p.updated_at).toISOString().slice(0, 10)}</lastmod>`
      : "";
    return `  <url><loc>${SITE_URL}/${escapeXml(p.slug)}</loc>${lastmod}</url>`;
  });

  const xml = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url><loc>${SITE_URL}/</loc></url>
${urls.join("\n")}
</urlset>`;

  return new Response(xml, {
    headers: {
      "Content-Type": "application/xml; charset=utf-8",
      "Cache-Control": "public, max-age=3600, s-maxage=3600",
      "Access-Control-Allow-Origin": SITE_URL,
      Vary: "Origin",
    },
  });
});
