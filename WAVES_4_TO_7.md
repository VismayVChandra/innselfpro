# InnSelf — Waves 4 to 7

Continues the numbering already in `supabase/migrations/`. Waves 1–3 (migrations 006–008) are done. This document specifies waves 4–7 (migrations 009–012).

Each item below is written to be implementable without further clarification: why it exists, the schema change, the files to touch, and what "done" means. Work waves in order — later waves assume earlier ones landed.

---

## House rules (follow the conventions already in this repo)

These are not suggestions; the existing code depends on them.

1. **Every migration is idempotent.** `create table if not exists`, `add column if not exists`, `drop policy if exists` before `create policy`, and `do $$ ... end $$` guards around constraint and publication changes. A partial run must be safe to re-run. See migration 006's header comment for why.

2. **Never put a cross-table `EXISTS` into an RLS policy on `jobs` or `bids`.** That caused error 42P17 (infinite recursion), fixed in migration 003. Use a `SECURITY DEFINER ... STABLE ... SET search_path = public` helper function that returns a narrow boolean/uuid, and `grant execute ... to authenticated`. Existing helpers to reuse: `job_belongs_to_customer`, `accepted_bid_technician`, `technician_has_bid_on_job`, `job_is_open`, `job_is_open_for_technician`.

3. **Clients never insert into `notifications`.** There is no insert policy and there must not be one. Notifications only ever come from `SECURITY DEFINER` trigger functions, so a notification always reflects something that actually happened.

4. **Constraint names.** `jobs_status_check` and `notifications_type_check` are Postgres's auto-generated names. When widening either, `drop constraint if exists` then re-add with the full value list. If a drop errors, run `\d jobs` / `\d notifications` in the SQL Editor and substitute the real name.

5. **Storage uploads** must be written under a path beginning with the uploader's own uid — that is the only thing the bucket policies in migration 002 check.

6. **Adding a table to realtime** goes through the guarded `pg_publication_tables` check used in migration 007, section 4.

7. **Code layout.** Keep the existing shape: `lib/features/<feature>/<feature>_repository.dart` for data access, `screens/` for full pages, `widgets/` for pieces, `lib/models/` for plain data classes, `lib/core/` for theme, formatting and shared widgets. New feature = new folder, same pattern.

8. **Android only.** There is no `ios/` directory in this project. Do not add iOS-specific setup.

---

## Wave 4 — Close the loop

**Migration:** `supabase/migrations/009_wave4_features.sql`

This wave is the difference between a working demo and an app two strangers can actually complete a job through. Do it before anything else.

### 4.1 Tap to call and WhatsApp

**Why.** `_ContactCard` in `job_detail_screen.dart` currently only copies the phone number to the clipboard. In practice the first thing both sides do once a bid is accepted is call each other, and right now that is: copy → leave app → open dialer → paste. `url_launcher` is not even in `pubspec.yaml`.

**Schema.** None.

**Client.**
- `pubspec.yaml`: add `url_launcher: ^6.3.0`.
- `android/app/src/main/AndroidManifest.xml`: add a `<queries>` block for `tel` and `https` intents. Android 11+ package visibility will silently make `canLaunchUrl` return false without it — this is the usual failure mode, do not skip it.
- `lib/core/format.dart`: add `String? normalisePhone(String raw)` — strip everything non-digit, drop a leading `0`, prepend `+91` when 10 digits remain, return null when the result is not a plausible number. `profiles.phone` is free text, so it must be normalised before use.
- `job_detail_screen.dart` → `_ContactCard`: replace the single copy icon with a row of three `_ContactAction`s — call (`tel:`), WhatsApp (`https://wa.me/<digits>`), copy (existing behaviour). Hide call/WhatsApp when `normalisePhone` returns null rather than showing a button that fails.

**Done when.** From an assigned job, one tap opens the dialer prefilled and one tap opens the WhatsApp thread; copy still works; a malformed stored number degrades to copy-only instead of erroring.

### 4.2 Push notifications

**Why.** The `notifications` table, its triggers, and `streamMyNotifications()` all exist, but Supabase realtime only delivers while the app is open. A technician with the app closed misses every job; a customer misses every bid. Everything already built is worth more once this lands.

**Schema (009).**
```sql
create table if not exists device_tokens (
  user_id uuid not null references profiles(id) on delete cascade,
  token text not null,
  platform text not null default 'android',
  updated_at timestamptz not null default now(),
  primary key (user_id, token)
);
alter table device_tokens enable row level security;
-- select / insert / update / delete, all `user_id = auth.uid()`
```

**Server.**
- New Edge Function `supabase/functions/send-push/index.ts`. Reads a notification row from the request body, looks up that user's device tokens with the service role, sends via FCM HTTP v1, and deletes tokens FCM reports as unregistered.
- Wire it with a **Supabase Database Webhook** on `notifications` INSERT pointing at the function. Prefer this over `pg_net` inside a trigger — no extension needed and failures do not roll back the insert.
- FCM service-account JSON goes in function secrets, never in the repo. `lib/core/env.dart` is gitignored and `env.example.dart` is the template — follow the same pattern for anything new.

**Client.**
- `pubspec.yaml`: `firebase_core`, `firebase_messaging`.
- `android/app/google-services.json` from a new Firebase project; add the Google services Gradle plugin in `android/build.gradle.kts` and `android/app/build.gradle.kts`.
- Register the token after sign-in and on `onTokenRefresh`; delete the row on sign-out (`AuthRepository.signOut`) — otherwise a shared phone keeps notifying the previous user.
- Notification tap opens `JobDetailScreen` for the payload's `job_id`. `NotificationBell` and the badge count keep working unchanged.

**Done when.** With the app fully closed, a technician receives a heads-up notification when a customer bids/requests, and tapping it lands on the right job.

### 4.3 New-job alerts to matching technicians

**Why.** Today a technician only discovers work by opening the Feed tab and pulling to refresh. There is no notification type for "a job was posted that you could do", so 4.2 has nothing useful to push to the supply side. This is the item that actually makes technicians open the app.

**Schema (009).**
- Widen `notifications_type_check` to include `'new_job'`.
- Trigger function `notify_matching_technicians()` — `after insert on jobs`, `security definer`. Skip when `invited_technician_id is not null` (that path already has `direct_request`). Otherwise insert one notification per technician whose `technician_skills` contains the job's `category_id`, excluding the posting customer, and — once 5.2 lands — excluding technicians marked unavailable.
- Cap the fan-out. Until 6.1 gives you real location matching, also require the technician's `service_area` to be null or to `ilike`-match the job location, and hard-limit to a sane number of recipients per job.

**Done when.** Posting a plumbing job in Koramangala notifies plumbers, does not notify electricians, and does not notify the customer who posted it.

### 4.4 Completion code

**Why.** `JobsRepository.completeJob()` lets the technician set `status = 'completed'` on his own, which immediately opens the customer's payment screen. If the customer disagrees, their only lever is the dispute flag — which is a fight, not a workflow. This is the trust failure that kills a marketplace in its first month.

**Schema (009).**
```sql
alter table jobs add column if not exists completion_code text;
alter table jobs add column if not exists customer_confirmed_at timestamptz;
```
- Trigger on `jobs` update: when status moves to `'bid_accepted'` and `completion_code is null`, generate a 4-digit code.
- `BEFORE UPDATE` guard trigger on `jobs`: raise an exception if `new.status = 'completed'`, `old.status is distinct from 'completed'`, and `new.customer_confirmed_at is null`. This is what actually enforces it — `jobs_update_assigned_technician` allows the technician to update any column, and tightening that policy is far more fragile than a guard trigger.
- `SECURITY DEFINER` RPC `complete_job_with_code(p_job_id uuid, p_code text, p_photo_url text)` — verifies the caller is the accepted technician and the code matches, then sets `status`, `completion_photo_url` and `customer_confirmed_at` in one statement. Rate-limit or lock out after ~5 wrong attempts so the code is not brute-forceable.

**Client.**
- Customer side of `job_detail_screen.dart`: show the code prominently once status is `bid_accepted` or later — "Give this code to your technician when the work is done."
- Technician side: the "Mark complete" flow takes the code (plus the optional completion photo it already takes) and calls the RPC. `JobsRepository.completeJob()` becomes a wrapper over the RPC.
- Keep the payment section gated on `'completed'` — no change needed there.

**Done when.** A technician cannot close a job without the customer reading out the code, and the customer's screen makes the code impossible to miss.

---

## Wave 5 — Coordination

**Migration:** `supabase/migrations/010_wave5_features.sql`

Wave 4 makes the loop close. This wave removes the reasons people currently leave the app mid-job.

### 5.1 Per-job chat

**Why.** "Which floor?" "Is the spare part included?" "Running 20 minutes late." All of that happens on WhatsApp today, so when a dispute arrives you have no record of what was agreed.

**Schema (010).**
```sql
create table if not exists messages (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references jobs(id) on delete cascade,
  sender_id uuid not null references profiles(id),
  body text not null,
  created_at timestamptz not null default now()
);
create index if not exists messages_job_id_idx on messages (job_id, created_at);
```
- RLS: select and insert restricted to the two participants — the owning customer (`job_belongs_to_customer`) and the accepted technician (`accepted_bid_technician`). **Open chat only after a bid is accepted**, not during bidding: it keeps the policy simple and stops the platform being bypassed before a job is booked.
- Add `messages` to the `supabase_realtime` publication, using the guarded pattern from migration 007.
- Widen `notifications_type_check` with `'new_message'` and add an `after insert` trigger notifying the other participant.

**Client.** New `lib/features/messages/` — `messages_repository.dart` (stream + send, same shape as `NotificationsRepository.streamMyNotifications`) and `screens/chat_screen.dart`. Entry point is a message action in `_ContactCard`, with an unread dot.

**Done when.** Both sides can exchange messages on an assigned job, messages appear live without a refresh, and the other party gets a push.

### 5.2 Technician availability

**Why.** Nothing currently stops a technician who is mid-job, asleep, or away for the week from being sent direct requests and appearing biddable. The "YOU ARE VISIBLE IN" panel on the feed also has nothing true to say.

**Schema (010).** `alter table technician_details add column if not exists is_available boolean not null default true;`

**Client.**
- A switch in the Feed header (`technician_home_screen.dart`, near `_AreaPanel`) and in `technician_profile_screen.dart`.
- `_AreaPanel` reflects the real state: available and visible in an area, available everywhere, or offline.
- Unavailable technicians are excluded from the 4.3 fan-out and from rebook/direct-request selection.

**Done when.** Toggling off stops new-job pushes and removes the technician from rebook lists, and the feed panel says so plainly.

### 5.3 On my way + ETA

**Why.** `JobStatusInfo` goes straight from "Technician assigned" to "Work in progress". The customer's single most common question — *when are they coming* — has no answer in the app. (Note: the doc comments in `job_status.dart` already describe a "five-step timeline" while `timeline` holds four entries; this closes that gap.)

**Schema (010).**
- Widen `jobs_status_check` to include `'en_route'`.
- `alter table jobs add column if not exists eta_at timestamptz;`
- Widen `notifications_type_check` with `'technician_en_route'` and add the trigger.

**Client.**
- `job_status.dart`: new `_enRoute` state between `_bidAccepted` and `_inProgress` — customer label "On the way", technician label "You are on the way", progress ~60. Add the matching timeline entry and update `isActive` / `showsTimeline`.
- Technician action "I'm on my way" with a time picker that sets `eta_at`.
- Customer status panel shows "Arriving by 3:40 PM" using the existing `formatDateTime` helper.

**Done when.** The customer can see, without calling, that the technician has left and roughly when they will arrive.

---

## Wave 6 — Matching

**Migration:** `supabase/migrations/011_wave6_features.sql`

### 6.1 Real location instead of free text

**Why.** `fetchOpenJobsFeed` filters area with `ilike '%<text>%'` against a free-text field. "Koramangla", "5th Block Koramangala" and "BTM / Koramangala" all silently fail to match, so technicians never see jobs they would happily have taken. This is the single biggest cause of an empty-looking feed.

**Schema (011).**
- `jobs`: add `pincode text`, `lat double precision`, `lng double precision`. Keep the existing free-text `location` as the human-readable address — the new columns are the machine-readable key, not a replacement.
- `technician_details`: add `service_pincodes text[]`, `base_lat double precision`, `base_lng double precision`, `service_radius_km int default 10`.
- `SECURITY DEFINER` RPC `open_jobs_for_technician(p_technician_id uuid, p_category_ids int[])` returning open, non-invite jobs with a computed `distance_km`, ordered nearest first. Plain haversine in SQL is enough — do not add PostGIS for this.

**Client.**
- `post_job_screen.dart`: pincode field (required) next to the address, plus an optional "use my current location" button (`geolocator`) that fills lat/lng.
- `technician_profile_setup_screen.dart` / edit profile: service pincodes and radius replace the free-text area box.
- `technician_home_screen.dart`: the area text field becomes a radius control; the feed calls the RPC. `JobFeedCard` shows "3.2 km away".
- Keep `fetchOpenJobsFeed` for the "All"/explicit-category paths, or fold both into the RPC — but do not leave two different definitions of "nearby".

**Done when.** The feed is sorted by real distance, spelling variations no longer hide jobs, and each card says how far away the work is.

### 6.2 Saved addresses

**Why.** `profiles.address` exists but Post Job starts with an empty location field every single time. A repeat customer retypes their address on every request.

**Schema (011).**
```sql
create table if not exists customer_addresses (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references profiles(id) on delete cascade,
  label text not null,
  address text not null,
  pincode text,
  lat double precision,
  lng double precision,
  is_default boolean not null default false,
  created_at timestamptz not null default now()
);
```
RLS: own rows only, all four operations.

**Client.** `post_job_screen.dart` shows saved addresses as selectable chips with an "Add new" option, preselecting the default. Manage them from `customer_profile_screen.dart`. Backfill each customer's first address from `profiles.address` on first use.

**Done when.** A returning customer posts a job without typing an address.

### 6.3 Job expiry and no-bid feedback

**Why.** Open jobs never close. The feed slowly fills with stale requests, and a customer who received zero bids is never told anything at all.

**Schema (011).**
- `alter table jobs add column if not exists expires_at timestamptz;` default `now() + interval '3 days'` for new rows.
- Widen `jobs_status_check` with `'expired'`.
- A scheduled Edge Function (Supabase cron, hourly) moves past-due `open` jobs to `'expired'` and notifies the customer — widen `notifications_type_check` with `'job_expired'`.
- Feed queries and the 4.3 fan-out exclude expired jobs.

**Client.** Customer activity screen shows expired requests with a one-tap "Repost" that opens `PostJobScreen` prefilled, suggesting a wider area or a different category. Reuse the existing `PriceGuidanceHint` to explain if their expectations were off.

**Done when.** Stale jobs leave the feed automatically and their customers get told why, with an easy way to try again.

---

## Wave 7 — Trust and operations

**Migration:** `supabase/migrations/012_wave7_features.sql`

### 7.1 KYC status and a verified badge

**Why.** `technician_kyc` stores the ID document and number but has no status column and nothing customer-facing. A customer choosing between three bids sees price and stars, and has no idea whether anyone checked who these people are.

**Schema (012).**
- `technician_kyc`: add `status text not null default 'pending' check (status in ('pending','verified','rejected'))`, `verified_at timestamptz`, `rejection_reason text`.
- `profiles`: add `is_verified boolean not null default false`, kept in sync by a trigger on `technician_kyc`. `technician_kyc` is owner-only by design and must stay that way — `profiles` is already readable by any authenticated user, so mirroring just the boolean is the clean way to expose it without leaking documents.

**Client.** A small verified badge on `_BidCard`, `_ContactCard`, and `technician_profile_screen`. On the technician's own profile, show pending / verified / rejected with the reason, so a rejected technician knows to resubmit.

**Done when.** A customer comparing bids can tell a verified technician from an unverified one.

### 7.2 Cancel and reschedule after acceptance

**Why.** `cancelJob` only works while the job is still open (RLS policy `bids_delete_own_pending` and the client both assume it). Once a technician is assigned, the only exit for either side is the dispute flow — so ordinary life events ("customer not home", "technician sick") get logged as disputes and poison both reputations.

**Schema (012).**
```sql
create table if not exists job_cancellations (
  job_id uuid primary key references jobs(id) on delete cascade,
  cancelled_by uuid not null references profiles(id),
  reason text not null,
  created_at timestamptz not null default now()
);
```
- Allow the transition to `'cancelled'` from `bid_accepted` and `en_route` (not from `in_progress` or `completed`) for either participant, recording a reason.
- Notify the other party — widen `notifications_type_check` with `'job_cancelled'`.
- Rescheduling is just an update to `scheduled_for` by either participant plus a notification; no new table.

**Client.** A "Can't make it" action on both sides with a short reason picker. Show a late-cancellation count on each profile so the signal is visible without being punitive.

**Done when.** Neither side has to file a dispute to handle a normal change of plan.

### 7.3 Admin surface

**Why.** Migration 001 says dispute resolution is "handled manually via the console", and KYC approval has no path at all. That is fine for ten users and impossible at a hundred.

**Schema (012).**
- `admins(user_id uuid primary key references profiles(id))`.
- `SECURITY DEFINER` helper `is_admin(p_user_id uuid)` — this is the same pattern used everywhere else and avoids recursion.
- Additional RLS policies letting admins select and update `disputes` and `technician_kyc`.

**Client.** A hidden route inside the existing app rather than a second deployment: a list of open disputes and pending KYC submissions, with approve/reject/close actions. Reachable only when `is_admin` returns true. If you would rather keep it out of the customer app entirely, a small Flutter Web target against the same Supabase project works too — but do the in-app version first.

**Done when.** Approving a technician and closing a dispute both happen without opening the Supabase console.

---

## Order of work

Do not batch these. Ship and test one wave at a time, in this order:

1. **Wave 4** — this is the one that matters. 4.1 is an hour. 4.2 + 4.3 together are the highest-value change in the whole document. 4.4 prevents your first serious argument between a customer and a technician.
2. **Wave 5** — coordination. Chat first if disputes are already happening; availability first if technicians are complaining about irrelevant requests.
3. **Wave 6** — matching. Do this before any real push for technician signups, or they will churn on an empty feed.
4. **Wave 7** — needed before real money and real strangers, not before the demo.

## Explicitly out of scope

Do not build these yet, even if they come up: in-app wallet and technician payouts, subscriptions or lead-credit packs, multi-language support, in-app maps and turn-by-turn navigation, rating sub-scores (punctuality / quality / cleanliness), and referral programs. Each of them is a wave of its own and none of them fixes a problem the app has today.
