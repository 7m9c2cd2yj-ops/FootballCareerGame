// Edge function: POST { "slot": 1 } with the player's access token.
// Reads the player's uploaded career for that slot (never a client-sent
// summary), checks it is a career the game can produce, then writes the
// ranking with the service role. Clients cannot write rankings themselves
// (see the row-level security in migrations/).
import { createClient } from "npm:@supabase/supabase-js@2.118.0";
import { LIMITS } from "./limits.ts";
import { checkCareer } from "./plausibility.ts";

function reply(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

Deno.serve(async (request: Request): Promise<Response> => {
  if (request.method !== "POST") return reply(405, { error: "use POST" });
  const admin = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    { auth: { persistSession: false } },
  );
  const token = (request.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  const { data: auth, error: authError } = await admin.auth.getUser(token);
  if (authError || !auth.user) return reply(401, { error: "not signed in" });
  const userId = auth.user.id;

  const body = await request.json().catch(() => null);
  const slot = Number(body?.slot);
  if (!Number.isInteger(slot) || slot < 1 || slot > 10) return reply(400, { error: "bad slot" });

  const { data: profile } = await admin.from("profiles")
    .select("display_name, server_id").eq("id", userId).maybeSingle();
  if (!profile) return reply(400, { error: "create a profile first" });

  const { data: saved } = await admin.from("careers")
    .select("envelope").eq("owner", userId).eq("slot", slot).maybeSingle();
  if (!saved) return reply(404, { error: "upload the career first" });

  const result = checkCareer(saved.envelope?.career, LIMITS);
  if (!result.ok || !result.summary) {
    return reply(422, { error: "career failed validation", problems: result.problems.slice(0, 10) });
  }
  const ranking = {
    owner: userId,
    slot,
    display_name: profile.display_name,
    server_id: profile.server_id,
    ...result.summary,
    updated_at: new Date().toISOString(),
  };
  const { error: writeError } = await admin.from("rankings").upsert(ranking, {
    onConflict: "owner,slot",
  });
  if (writeError) return reply(500, { error: "could not save ranking" });
  return reply(200, { ranking });
});
