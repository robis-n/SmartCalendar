// Sign in with a username instead of an email.
//
// The username -> email lookup happens here, on the server, and the email
// never leaves it. Unknown usernames and wrong passwords get the same answer,
// so this cannot be used to find out who has an account or what their email is.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

const invalid = () => json({ error: "invalid_credentials" }, 401);

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  let payload: { username?: unknown; password?: unknown };
  try {
    payload = await req.json();
  } catch {
    return json({ error: "bad_json" }, 400);
  }

  const username = typeof payload.username === "string" ? payload.username.trim() : "";
  const password = typeof payload.password === "string" ? payload.password : "";
  if (!username || !password || username.length > 64 || password.length > 256) {
    return invalid();
  }

  try {
    const admin = createClient(SUPABASE_URL, SERVICE_KEY, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: email, error } = await admin.rpc("email_for_username", { p: username });
    if (error) {
      console.error("login-with-username lookup error", error.message);
      return json({ error: "login_failed" }, 502);
    }
    if (typeof email !== "string" || !email) return invalid();

    const res = await fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=password`, {
      method: "POST",
      headers: { "Content-Type": "application/json", apikey: ANON_KEY },
      body: JSON.stringify({ email, password }),
    });
    const body = await res.json().catch(() => ({}));

    if (!res.ok) {
      if (body?.error_code === "email_not_confirmed") {
        return json({ error: "email_not_confirmed" }, 401);
      }
      if (res.status === 429) return json({ error: "rate_limited" }, 429);
      return invalid();
    }
    if (!body?.refresh_token) return json({ error: "login_failed" }, 502);

    // Only the tokens go back. No email, no user record.
    return json({
      access_token: body.access_token,
      refresh_token: body.refresh_token,
    });
  } catch (e) {
    console.error("login-with-username error", e);
    return json({ error: "login_failed" }, 502);
  }
});
