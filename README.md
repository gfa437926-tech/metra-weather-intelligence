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
- Supabase initialization and email/password sign-in are enabled when compile-time configuration is provided.
- Station data is fetched through the `station-directory` Edge Function.
- The function verifies the user's JWT and requires `metra_account_states.account_state = active`.
- It returns non-demo station catalogue records and their current valid coordinates.
- Direct client access to protected tables remains denied by RLS.
- The function uses the server-side `SUPABASE_SERVICE_ROLE_KEY`; it is never sent to Flutter.
- Station type, approval state and operational state are displayed distinctly.

Deploy with Supabase CLI:
```bash
supabase functions deploy station-directory --project-ref tbdnklyxjvbrilvnwgmq
```
Keep JWT verification enabled.

## Data integrity and current integrations
- The home screen current conditions and hourly forecast are retrieved from Open-Meteo for Riyadh. They are not station telemetry.
- Station catalogue records and coordinates are read from the new Supabase project through the authenticated Edge Function.
- The map uses OpenStreetMap tiles. Overlapping identical coordinates are grouped so all associated station records remain discoverable.
- Official weather alerts, station-specific telemetry and radar/precipitation/temperature/wind map layers are not yet connected; the UI reports this rather than inventing data.
- Station approval and operational statuses are displayed from stored values. Pending/unverified stations are not presented as operational.

## Official Saudi weather data integration status
The Saudi National Center for Meteorology (NCM) documents a direct API integration service for real-time weather information, forecasts and early warnings. Access is subscription-based and requires an approved integration request and credentials. The NCM API documentation also describes station observations, WMS/WFS-compatible areal data, and official notification endpoints. METRA does not currently have verified NCM integration credentials configured, so these services are intentionally not called and no official-alert feed is represented as live.
- NCM API documentation: https://api-doc.ncm.gov.sa/
- NCM direct API integration: https://www.ncm.gov.sa/en/services/our-services/direct-api-integration
- NCM official developer guide: https://www.ncm.gov.sa/Ar/EService/Documents/developers/EWS%20APIs%20Technical%20Guide%20V.1.9.pdf

## Database safety
No schema or data changes were made to the new database during the current integration work. The legacy database and legacy repository are outside the scope of all changes. Do not run destructive migrations or updates against either.

## CI
GitHub Actions runs:
1. `flutter pub get`
2. `flutter analyze`
3. `flutter test`
4. `flutter build web --release`
5. Uploads `build/web` as the `metra-web-release` artifact.
