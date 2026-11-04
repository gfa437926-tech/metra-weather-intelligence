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
- Registration is submitted through the JWT-protected `registration` Edge Function and an authenticated `public.submit_metra_registration` wrapper. The wrapper binds the request to `auth.uid()`, rejects non-requestable roles and demo/invalid-authority stations, and delegates to the private idempotent registration transaction.
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
```
Keep JWT verification enabled for both functions. The registration SQL entry point is tracked in `supabase/migrations/202611040001_registration_authenticated_entrypoint.sql`.

## Data integrity and current integrations
- The home screen current conditions and hourly forecast are retrieved from Open-Meteo for Riyadh. They are not station telemetry.
- Station catalogue records and coordinates are read from the new Supabase project through the authenticated Edge Function.
- The map uses OpenStreetMap tiles. Overlapping identical coordinates are grouped; selecting a marker opens every station record at that location, including classic, automatic and unclassified stations. Invalid or expired coordinates are not plotted.
- Current coordinate history is paginated and validated; an invalid newest coordinate does not hide an older valid coordinate.
- Official weather alerts, station-specific telemetry and radar/precipitation/temperature/wind map layers are not yet connected; the UI reports this rather than inventing data.
- Station approval and operational statuses are displayed from stored values. Pending/unverified stations are not presented as operational.

## Official Saudi weather data integration status
The Saudi National Center for Meteorology (NCM) documents a direct API integration service for real-time weather information, forecasts and early warnings. Access is subscription-based and requires an approved integration request and credentials. The NCM API documentation also describes station observations, WMS/WFS-compatible areal data, and official notification endpoints. METRA does not currently have verified NCM integration credentials configured, so these services are intentionally not called and no official-alert feed is represented as live.
- NCM API documentation: https://api-doc.ncm.gov.sa/
- NCM direct API integration: https://www.ncm.gov.sa/en/services/our-services/direct-api-integration
- NCM official developer guide: https://www.ncm.gov.sa/Ar/EService/Documents/developers/EWS%20APIs%20Technical%20Guide%20V.1.9.pdf

## Database safety
The new METRA database now contains an authenticated registration entry-point function and its grants, tracked as a migration. Existing station and legacy-source records were not rewritten or deleted. The legacy database and legacy repository are outside the scope of all changes. Do not run destructive migrations or updates against either.

## CI
GitHub Actions runs:
1. Type-checks the `station-directory` and `registration` Edge Functions with Deno.
2. Tests the station-directory permission rules with Deno.
3. `flutter pub get`
3. `flutter analyze`
4. `flutter test`
5. `flutter build web --release`
6. Uploads `build/web` as the `metra-web-release` artifact.
