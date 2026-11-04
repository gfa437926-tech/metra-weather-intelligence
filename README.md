# METRA Weather Intelligence

Flutter/Dart weather platform with Arabic RTL interface.

## Run locally
```bash
flutter pub get
flutter run --dart-define=SUPABASE_URL=https://tbdnklyxjvbrilvnwgmq.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_SUPABASE_PUBLISHABLE_KEY
```

Use only the Supabase publishable key in client applications. Never include a Supabase secret or service-role key in Flutter or source control.

## Web release
```bash
flutter build web --release --dart-define=SUPABASE_URL=https://tbdnklyxjvbrilvnwgmq.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_SUPABASE_PUBLISHABLE_KEY
```
The web build is generated in `build/web`. GitHub Actions uploads a CI artifact named `metra-web-release` after analysis and tests pass. The artifact is a build output, not an automatically hosted public website.

## Supabase station directory
- Supabase initialization, email/password sign-in, and account creation are enabled when compile-time configuration is provided.
- Authenticated users without a METRA account are routed to the registration form; pending/rejected accounts cannot enter the application shell.
- Registration roles are read from the active, requestable role catalogue. Station choices are marked with their stored approval status.
- Registration is submitted through the JWT-protected `registration` Edge Function. The function derives the applicant ID from the verified JWT and invokes a server-only RPC using the service-role client.
- The `registration-approvals` Edge Function exposes only actionable review items allowed by active direct approval grants and approved station assignments. The function derives the reviewer ID from the verified JWT and delegates to the private two-stage approval transaction.
- The `observations` Edge Function provides station-scoped observation drafts, submission, review queues, approval, and return-for-correction. It verifies the caller JWT, active account, current station assignment and exact observation permission before exposing data or invoking server-only database transactions.
- The registration RPC wrappers are executable only by `service_role`, not `anon` or `authenticated`. The submission transaction pins the accepted terms version, uses database time, rejects non-requestable roles and demo/invalid-authority stations, and delegates to the private idempotent registration transaction. The approval Edge Function verifies the reviewer JWT before invoking the server-only decision RPC; the private transaction rechecks active account, direct grants, station assignment, and independent two-stage review.
- Station data is fetched through the `station-directory` Edge Function.
- The function verifies the user's JWT and requires `metra_account_states.account_state = active`.
- It returns non-demo station catalogue records and their current valid coordinates.
- Direct client access to protected tables remains denied by RLS.
- The function uses the server-side `SUPABASE_SERVICE_ROLE_KEY`; it is never sent to Flutter.
- Station type, approval state and operational state are displayed distinctly.

Deploy with Supabase CLI:
```bash
supabase functions deploy station-directory --project-ref tbdnklyxjvbrilvnwgmq
supabase functions deploy registration --project-ref tbdnklyxjvbrilvnwgmq
supabase functions deploy registration-approvals --project-ref tbdnklyxjvbrilvnwgmq
supabase functions deploy observations --project-ref tbdnklyxjvbrilvnwgmq
```
Keep JWT verification enabled for all four functions. The registration SQL entry point and server-side terms/time validation are tracked in `supabase/migrations/20261104014631_registration_authenticated_entrypoint.sql` and `supabase/migrations/20261104014827_registration_server_timestamp_and_terms_guard.sql`,  `supabase/migrations/20261104015029_authenticated_registration_decision_entrypoint.sql`, and `supabase/migrations/20261104015823_restrict_registration_rpc_to_server_runtime.sql`.

## Account and approval bootstrap prerequisites
- The inspected database currently has 62 non-demo station records, all pending/unverified, 50 coordinate-history rows, zero active METRA accounts, and zero submitted registration requests.
- The registration form can create a pending request, but a request cannot advance until its selected station is approved and operationally active.
- Station-stage reviewers require an active account, the direct `registrations.station.approve` grant, and an approved assignment to the requested station. System-stage reviewers require the separate `registrations.system.approve` grant and must be different from the station-stage reviewer.
- No initial administrator or approval grants are fabricated by the application. Provision the first authorized administrator and station reviewers through a controlled administrative procedure before production onboarding. Never grant broad permissions to arbitrary accounts.

## Data integrity and current integrations
- The home screen current conditions and hourly forecast are retrieved from Open-Meteo for Riyadh. They are not station telemetry.
- Station catalogue records and coordinates are read from the new Supabase project through the authenticated Edge Function.
- The map uses OpenStreetMap tiles. Overlapping identical coordinates are grouped; selecting a marker opens every station record at that location, including classic, automatic and unclassified stations. Invalid or expired coordinates are not plotted.
- Current coordinate history is paginated and validated; an invalid newest coordinate does not hide an older valid coordinate.
- Operational observation entry and review are available through the authenticated observations service. These are manually entered station readings; no automatic station telemetry is claimed.
- Official weather alerts and radar/precipitation/temperature/wind map layers are not yet connected; the UI reports this rather than inventing data.
- Station approval and operational statuses are displayed from stored values. Pending/unverified stations are not presented as operational.

## Official Saudi weather data integration status
The Saudi National Center for Meteorology (NCM) documents a direct API integration service for real-time weather information, forecasts and early warnings. Access is subscription-based and requires an approved integration request and credentials. The NCM API documentation also describes station observations, WMS/WFS-compatible areal data, and official notification endpoints. METRA does not currently have verified NCM integration credentials configured, so these services are intentionally not called and no official-alert feed is represented as live.
- NCM API documentation: https://api-doc.ncm.gov.sa/
- NCM direct API integration: https://www.ncm.gov.sa/en/services/our-services/direct-api-integration
- NCM official developer guide: https://www.ncm.gov.sa/Ar/EService/Documents/developers/EWS%20APIs%20Technical%20Guide%20V.1.9.pdf

## Database safety
The new METRA database now contains registration submission and two-stage decision entry points restricted to the server runtime, with database-side validation tracked as migrations. The security advisor currently reports no security lint findings. Existing station and legacy-source records were not rewritten or deleted. The legacy database and legacy repository are outside the scope of all changes. Do not run destructive migrations or updates against either.

## CI
GitHub Actions runs:
1. Type-checks the `station-directory`, `registration`, `registration-approvals`, and `observations` Edge Functions with Deno.
2. Tests the station-directory permission rules with Deno.
3. `flutter pub get`
4. `flutter analyze`
5. `flutter test`
6. `flutter build web --release`
7. Uploads `build/web` as the `metra-web-release` artifact.
\n## Station catalogue review\nThe station review transaction is applied to the METRA Supabase database under migration `20261104110000_secure_station_catalogue_review`. The public RPC is executable only by `service_role`; the Edge Function verifies the caller JWT, active METRA account and explicit time-bounded review grant. Decisions are `approved`, `rejected`, or `changes_requested`, each with a reason of at least five characters. Catalogue approval is intentionally separate from operational verification/activation. Do not grant `stations.catalogue.review` until an authorized real reviewer has been identified and provisioned through the controlled identity process.\n