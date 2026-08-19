// Razorpay calls this directly (server-to-server) when a payment is
// captured. This is the ONLY place payments.status is ever set to "paid" --
// the app never marks its own payment as paid.
//
// Required secret: RAZORPAY_WEBHOOK_SECRET (set when you create the webhook
// in the Razorpay dashboard, then copy the same value into Supabase Studio
// -> Edge Functions -> Secrets).

import { createClient } from "jsr:@supabase/supabase-js@2";

async function verifySignature(body: string, signature: string, secret: string) {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const mac = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(body));
  const expected = Array.from(new Uint8Array(mac))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
  return expected === signature;
}

Deno.serve(async (req) => {
  try {
    const signature = req.headers.get("x-razorpay-signature");
    const rawBody = await req.text();
    const secret = Deno.env.get("RAZORPAY_WEBHOOK_SECRET")!;

    if (!signature || !(await verifySignature(rawBody, signature, secret))) {
      return new Response(JSON.stringify({ error: "Invalid signature" }), { status: 401 });
    }

    const event = JSON.parse(rawBody);
    if (event.event !== "payment.captured") {
      // Ack anything we don't care about so Razorpay stops retrying it.
      return new Response(JSON.stringify({ ok: true, ignored: event.event }), { status: 200 });
    }

    const payment = event.payload?.payment?.entity;
    const orderId = payment?.order_id;
    const paymentId = payment?.id;
    if (!orderId || !paymentId) {
      return new Response(JSON.stringify({ error: "Malformed payload" }), { status: 400 });
    }

    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    await admin
      .from("payments")
      .update({
        status: "paid",
        razorpay_payment_id: paymentId,
        paid_at: new Date().toISOString(),
      })
      .eq("razorpay_order_id", orderId);

    return new Response(JSON.stringify({ ok: true }), { status: 200 });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
  }
});
