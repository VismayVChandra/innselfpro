# InnSelf

A two-sided marketplace Android app connecting customers with local
technicians — plumbers, electricians, carpenters, AC repair and so on.
Customers post a job, technicians bid, and the app carries the work
through scheduling, live status, payment and reviews.

Built with Flutter (Android only) on Supabase, with Razorpay for
payments and Firebase Cloud Messaging for push.

## Stack

| Piece | Choice |
| --- | --- |
| App | Flutter, Android only (there is no `ios/` directory) |
| Backend | Supabase — Postgres + Row Level Security + Edge Functions + Storage |
| Auth | Email/password only |
| Payments | Razorpay (online) plus a cash-settlement path |
| Push | Firebase Cloud Messaging via a `pg_net` trigger |

## Getting set up

The repo deliberately carries no credentials. Four things have to be
supplied locally before it will build and run:

1. **Supabase keys** — copy `lib/core/env.example.dart` to
   `lib/core/env.dart` and fill in your project URL and publishable key.
2. **Firebase** — create a Firebase project, register an Android app
   with package `com.innself.app`, and drop `google-services.json` into
   `android/app/`. The Google services Gradle plugin is applied
   unconditionally, so the build fails without it.
3. **Release signing** *(only for release builds)* — `android/key.properties`
   plus the keystore it points at. Absent, the build falls back to debug
   signing.
4. **Migrations** — run everything in `supabase/migrations/` in order,
   in the Supabase SQL Editor. Several are templates: read the header
   comment before running. `011_send_push_trigger.sql` in particular has
   placeholders that must be substituted first, and will refuse to run
   otherwise.

Then:

```bash
flutter pub get
flutter run
```

## Edge Functions

Deployed separately with the Supabase CLI (`npx supabase functions deploy <name>`):

| Function | Purpose | JWT verification |
| --- | --- | --- |
| `create-razorpay-order` | Creates an order for the app to pay against | On |
| `razorpay-webhook` | Razorpay calls this to confirm capture — the only place a payment is marked paid | **Off** (external caller) |
| `delete-account` | Hard-deletes a clean account, anonymises one with history | On |
| `send-push` | Sends FCM push for a new notification row | On |

`send-push` needs an `FCM_SERVICE_ACCOUNT_JSON` secret — the JSON key of
a Firebase service account with the Cloud Messaging Admin role.

## What's built

Everything below is implemented. The numbered stages came first, then
the feature waves.

**Core (stages 1–10):** auth, customer and technician profiles with KYC
upload, job posting and feed, bidding and acceptance, status tracking,
Razorpay and cash payment, two-way reviews, technician wallet, in-app
notifications, dispute flagging.

**Wave 1–3:** cash payments, scheduling, profile editing, account
deletion, structured skills, completion photos, realtime feed and bids,
rebooking a technician directly, multiple job photos, price guidance
from historical accepted bids.

**Wave 4 — closing the loop:** tap-to-call and WhatsApp, FCM push
notifications, new-job alerts fanned out to matching technicians, and a
4-digit completion code the customer reads out before a job can be
marked done.

**Wave 5 — coordination:** per-job chat, a technician availability
toggle, and an "on my way" status with an ETA.

**Wave 6 — matching:** real latitude/longitude matching with a service
radius replacing free-text area names, saved customer addresses, and
automatic expiry of jobs that attract no bids.

**Wave 7 — trust and operations:** KYC review states with a
customer-facing verified badge, cancel-with-reason and reschedule after
a technician is assigned, and an in-app admin surface for approving KYC
and closing disputes.

## Admin access

There is no in-app path to becoming an admin, by design. Grant it
directly:

```sql
insert into admins (user_id) values ('<profile-uuid>');
```

An "Admin" row then appears in that account's profile tab.

## Conventions

- **Migrations are idempotent.** `create table if not exists`,
  `drop policy if exists` before `create policy`, `do $$ ... end $$`
  guards around constraint and publication changes. A partial run must
  be safe to re-run.
- **Never put a cross-table `EXISTS` in an RLS policy on `jobs` or
  `bids`.** That caused infinite recursion (error 42P17) once already.
  Use a `SECURITY DEFINER ... STABLE` helper returning a narrow
  boolean or uuid instead — several already exist.
- **Clients never insert into `notifications`.** Only `SECURITY DEFINER`
  trigger functions do, so a notification always reflects something that
  actually happened. `job_cancellations` follows the same rule.
- **Layout:** `lib/features/<feature>/` with `<feature>_repository.dart`
  for data access, `screens/` for pages, `widgets/` for pieces;
  `lib/models/` for plain data classes; `lib/core/` for theme,
  formatting and shared widgets.
