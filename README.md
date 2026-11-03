# METRA Weather Intelligence

Flutter/Dart weather platform with Arabic RTL interface.

## Run locally
```bash
flutter pub get
flutter run --dart-define=SUPABASE_URL=https://tbdnklyxjvbrilvnwgmq.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_SUPABASE_PUBLISHABLE_KEY
```

Use only the publishable key in client applications. Never include a Supabase secret or service-role key in Flutter or source control.

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

## Data integrity
No database schema or data changes were made by this integration. The legacy database remains untouched. The station map now uses OpenStreetMap tiles and renders all returned station coordinates with distinct classic/automatic symbols. Unlocated stations remain in the directory but naturally have no map marker. The home screen readings and radar layers remain placeholders, not live weather or radar data.

## CI
GitHub Actions runs `flutter pub get`, `flutter analyze lib`, and `flutter test`.
