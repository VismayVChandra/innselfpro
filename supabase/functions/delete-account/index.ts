// Deletes or anonymizes the calling user's own account. Required for
// Google Play's account-deletion policy.
//
// jobs/bids/payments/reviews all reference profiles(id) with NO ACTION
// (not cascade), so a profile with any history can't be hard-deleted
// without either orphaning the other party's records or failing the FK
// check outright. So:
//   - No job/bid history at all -> hard delete (auth.users cascades to
//     profiles, which cascades to technician_details/technician_kyc).
//   - Has history, but nothing currently in flight -> anonymize
//     (name/phone/address scrubbed, login permanently banned) and keep
//     the transaction rows intact for whoever they worked with.
//   - Has a job actively in flight (open/bid_accepted/in_progress, on
//     either side) -> refuse outright, so nobody vanishes out from
//     under a live job.
//
// No secrets beyond the ones already required by the other functions
// (SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, both auto-provided).

import { createClient } from "jsr:@supabase/supabase-js@2";

const ACTIVE_STATUSES = ["open", "bid_accepted", "in_progress"];

Deno.serve(async (req) => {
  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing Authorization header" }), {
        status: 401,
      });
    }

    const callerClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } },
    );
    const { data: userData, error: userError } = await callerClient.auth.getUser();
    if (userError || !userData.user) {
      return new Response(JSON.stringify({ error: "Invalid session" }), { status: 401 });
    }
    const uid = userData.user.id;

    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // Active as a customer?
    const { data: activeAsCustomer } = await admin
      .from("jobs")
      .select("id")
      .eq("customer_id", uid)
      .in("status", ACTIVE_STATUSES)
      .limit(1);
    if (activeAsCustomer && activeAsCustomer.length > 0) {
      return new Response(
        JSON.stringify({ error: "You have a job in progress. Cancel or finish it before deleting your account." }),
        { status: 400 },
      );
    }

    // Active as the technician on an accepted bid?
    const { data: acceptedBids } = await admin
      .from("bids")
      .select("job_id")
      .eq("technician_id", uid)
      .eq("status", "accepted");
    if (acceptedBids && acceptedBids.length > 0) {
      const jobIds = acceptedBids.map((b) => b.job_id);
      const { data: activeAsTechnician } = await admin
        .from("jobs")
        .select("id")
        .in("id", jobIds)
        .in("status", ACTIVE_STATUSES)
        .limit(1);
      if (activeAsTechnician && activeAsTechnician.length > 0) {
        return new Response(
          JSON.stringify({ error: "You have a job in progress. Finish it before deleting your account." }),
          { status: 400 },
        );
      }
    }

    // Any history at all, on either side?
    const { count: jobCount } = await admin
      .from("jobs")
      .select("id", { count: "exact", head: true })
      .eq("customer_id", uid);
    const { count: bidCount } = await admin
      .from("bids")
      .select("id", { count: "exact", head: true })
      .eq("technician_id", uid);
    const hasHistory = (jobCount ?? 0) > 0 || (bidCount ?? 0) > 0;

    // KYC documents are sensitive regardless of history -- always wipe
    // them, along with the profile_id-keyed rows that reference them.
    const { data: kycFiles } = await admin.storage.from("technician-kyc").list(uid);
    if (kycFiles && kycFiles.length > 0) {
      await admin.storage
        .from("technician-kyc")
        .remove(kycFiles.map((f) => `${uid}/${f.name}`));
    }
    await admin.from("technician_kyc").delete().eq("profile_id", uid);
    await admin.from("technician_details").delete().eq("profile_id", uid);

    if (!hasHistory) {
      const { error: deleteError } = await admin.auth.admin.deleteUser(uid);
      if (deleteError) {
        return new Response(JSON.stringify({ error: deleteError.message }), { status: 500 });
      }
      return new Response(JSON.stringify({ ok: true, mode: "deleted" }), { status: 200 });
    }

    await admin
      .from("profiles")
      .update({ full_name: "Deleted user", phone: "", address: null })
      .eq("id", uid);

    // ~100 years -- effectively permanent, without a magic sentinel value.
    await admin.auth.admin.updateUserById(uid, { ban_duration: "876000h" });

    return new Response(JSON.stringify({ ok: true, mode: "anonymized" }), { status: 200 });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
  }
});
