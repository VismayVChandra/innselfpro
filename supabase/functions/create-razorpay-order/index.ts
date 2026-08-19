// Creates a Razorpay order for a completed job and upserts the payments row.
// Called by the customer from the app after a job is marked "completed".
// The amount is always computed server-side from the accepted bid --
// never trusted from the client.
//
// Required secrets (set in Supabase Studio -> Edge Functions -> Secrets):
//   RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET
// Auto-provided by Supabase: SUPABASE_URL, SUPABASE_ANON_KEY,
//   SUPABASE_SERVICE_ROLE_KEY

import { createClient } from "jsr:@supabase/supabase-js@2";

Deno.serve(async (req) => {
  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing Authorization header" }), {
        status: 401,
      });
    }

    const { jobId } = await req.json();
    if (!jobId) {
      return new Response(JSON.stringify({ error: "jobId is required" }), { status: 400 });
    }

    // Client scoped to the caller's JWT, used only to identify who is calling.
    const callerClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } },
    );
    const { data: userData, error: userError } = await callerClient.auth.getUser();
    if (userError || !userData.user) {
      return new Response(JSON.stringify({ error: "Invalid session" }), { status: 401 });
    }
    const customerId = userData.user.id;

    // Service-role client for the trusted, authoritative reads/writes below.
    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { data: job, error: jobError } = await admin
      .from("jobs")
      .select("id, customer_id, status, accepted_bid_id")
      .eq("id", jobId)
      .single();
    if (jobError || !job) {
      return new Response(JSON.stringify({ error: "Job not found" }), { status: 404 });
    }
    if (job.customer_id !== customerId) {
      return new Response(JSON.stringify({ error: "Not your job" }), { status: 403 });
    }
    if (job.status !== "completed") {
      return new Response(JSON.stringify({ error: "Job is not completed yet" }), {
        status: 400,
      });
    }
    if (!job.accepted_bid_id) {
      return new Response(JSON.stringify({ error: "Job has no accepted bid" }), {
        status: 400,
      });
    }

    const { data: existingPayment } = await admin
      .from("payments")
      .select("status")
      .eq("job_id", jobId)
      .maybeSingle();
    if (existingPayment?.status === "paid") {
      return new Response(JSON.stringify({ error: "Job already paid" }), { status: 400 });
    }

    const { data: bid, error: bidError } = await admin
      .from("bids")
      .select("amount, technician_id")
      .eq("id", job.accepted_bid_id)
      .single();
    if (bidError || !bid) {
      return new Response(JSON.stringify({ error: "Accepted bid not found" }), { status: 404 });
    }

    const amountInPaise = Math.round(Number(bid.amount) * 100);
    const keyId = Deno.env.get("RAZORPAY_KEY_ID")!;
    const keySecret = Deno.env.get("RAZORPAY_KEY_SECRET")!;
    const basicAuth = btoa(`${keyId}:${keySecret}`);

    const orderRes = await fetch("https://api.razorpay.com/v1/orders", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Basic ${basicAuth}`,
      },
      body: JSON.stringify({
        amount: amountInPaise,
        currency: "INR",
        receipt: jobId,
      }),
    });
    const order = await orderRes.json();
    if (!orderRes.ok) {
      return new Response(JSON.stringify({ error: "Razorpay order creation failed", details: order }), {
        status: 502,
      });
    }

    await admin.from("payments").upsert({
      job_id: jobId,
      customer_id: customerId,
      technician_id: bid.technician_id,
      amount: bid.amount,
      razorpay_order_id: order.id,
      status: "created",
    }, { onConflict: "job_id" });

    return new Response(
      JSON.stringify({
        orderId: order.id,
        amount: amountInPaise,
        currency: "INR",
        keyId,
      }),
      { status: 200, headers: { "Content-Type": "application/json" } },
    );
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
  }
});
