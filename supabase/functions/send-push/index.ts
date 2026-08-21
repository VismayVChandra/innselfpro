// Invoked by a Supabase Database Webhook on `notifications` INSERT (set up
// in the dashboard, not via SQL migration -- see the wave 4 doc). Looks up
// the notified user's device tokens and sends a push via FCM HTTP v1.
//
// Required secret: FCM_SERVICE_ACCOUNT_JSON -- the full JSON key of a
// Firebase service account with the "Firebase Cloud Messaging API Admin"
// role, as a single-line string (Supabase Studio -> Edge Functions ->
// Secrets). Never commit this file with a real key inline.
//
// A webhook (rather than pg_net inside a trigger) is deliberate: a failure
// here can't roll back the notification insert that triggered it.

import { createClient } from "jsr:@supabase/supabase-js@2";

interface ServiceAccount {
  client_email: string;
  private_key: string;
  project_id: string;
}

interface NotificationRecord {
  id: string;
  user_id: string;
  type: string;
  job_id: string | null;
  message: string;
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const base64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s/g, "");
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes.buffer;
}

function base64UrlEncode(data: string | ArrayBuffer): string {
  const bytes = typeof data === "string"
    ? new TextEncoder().encode(data)
    : new Uint8Array(data);
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function getAccessToken(serviceAccount: ServiceAccount): Promise<string> {
  const header = base64UrlEncode(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const now = Math.floor(Date.now() / 1000);
  const claims = base64UrlEncode(JSON.stringify({
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  }));
  const unsigned = `${header}.${claims}`;

  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToArrayBuffer(serviceAccount.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsigned),
  );
  const jwt = `${unsigned}.${base64UrlEncode(signature)}`;

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  if (!res.ok) {
    throw new Error(`Failed to mint FCM access token: ${await res.text()}`);
  }
  const { access_token } = await res.json();
  return access_token as string;
}

function titleFor(type: string): string {
  switch (type) {
    case "new_bid": return "New bid received";
    case "bid_accepted": return "Your bid was accepted";
    case "job_completed": return "Job marked complete";
    case "payment_received": return "Payment received";
    case "direct_request": return "You've been requested directly";
    case "new_job": return "New job near you";
    default: return "InnSelf";
  }
}

Deno.serve(async (req) => {
  try {
    const serviceAccount: ServiceAccount = JSON.parse(
      Deno.env.get("FCM_SERVICE_ACCOUNT_JSON")!,
    );
    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const payload = await req.json();
    const notification: NotificationRecord | undefined = payload.record;
    if (!notification) {
      return new Response(JSON.stringify({ error: "Missing notification record" }), { status: 400 });
    }

    const { data: tokens, error } = await admin
      .from("device_tokens")
      .select("token")
      .eq("user_id", notification.user_id);
    if (error) throw error;
    if (!tokens || tokens.length === 0) {
      return new Response(JSON.stringify({ ok: true, sent: 0 }), { status: 200 });
    }

    const accessToken = await getAccessToken(serviceAccount);
    let sent = 0;
    const deadTokens: string[] = [];

    for (const { token } of tokens) {
      const res = await fetch(
        `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`,
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${accessToken}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            message: {
              token,
              notification: {
                title: titleFor(notification.type),
                body: notification.message,
              },
              data: {
                job_id: notification.job_id ?? "",
                type: notification.type,
              },
              android: { priority: "high" },
            },
          }),
        },
      );
      if (res.ok) {
        sent++;
      } else {
        const body = await res.json().catch(() => null);
        const status = body?.error?.details?.[0]?.errorCode;
        if (status === "UNREGISTERED" || status === "NOT_FOUND" || status === "INVALID_ARGUMENT") {
          deadTokens.push(token);
        }
      }
    }

    if (deadTokens.length > 0) {
      await admin.from("device_tokens").delete().eq("user_id", notification.user_id).in("token", deadTokens);
    }

    return new Response(JSON.stringify({ ok: true, sent, pruned: deadTokens.length }), { status: 200 });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
  }
});
