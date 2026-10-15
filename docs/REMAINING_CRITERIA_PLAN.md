# Musico Remaining Course Criteria Plan

> Execution mode: native implementation in the current task, authorized by the user's request to finish the project.

**Goal:** Close remaining implementable course criteria for topic 19 (Music Player), using Supabase for application backend services and documenting items that require owner credentials, physical-device review, or store accounts.

**Architecture:** Keep the existing Flutter presentation and Supabase repository, add a BLoC as the application-level playback controller, consolidate tab routing in a GoRouter shell, and add a location-aware concert venue feature backed by Supabase. Keep platform and deployment credentials outside source control.

**Tech Stack:** Flutter/Dart stable, flutter_bloc, GoRouter, Supabase Auth/Postgres/Storage/Edge Functions, Hive, SharedPreferences, Google Maps, geolocator, GitHub Actions.

**Spec:** Course requirements in `individual_project_flutter_ru.docx` and `Вставленный текст.txt`; user-selected topic 19.

## Global constraints

- Preserve null safety and the current user's local Supabase URL and public key in ignored local configuration only.
- Never place Supabase secret keys, database passwords, signing keys, OAuth secrets, or push service credentials in Flutter assets or Git.
- Keep authentication and user-owned records protected by Postgres RLS.
- Supabase replaces Firebase Auth and Firestore; platform push transport and crash delivery must be described accurately if external provider configuration remains necessary.
- Verify each code change with focused tests, the full test suite, analyzer, and builds where the local SDK supports them.

## File ownership and implementation order

1. **State and routing:** `lib/features/player/`, `lib/main.dart`, relevant screen controls. BLoC owns playback command/state flow; GoRouter `ShellRoute` owns persistent bottom tabs. Test state transitions and tab navigation.
2. **Music venue map:** `lib/features/venues/`, `lib/data/music_repository.dart`, Supabase SQL migration, Android/iOS app configuration. Geolocation permission denial must show a usable map fallback; venue markers open details. Map SDK key remains an owner-provided public, restricted key.
3. **Supabase backend:** additive migration with venue/notification/crash-report data, grants, RLS, optional Edge Functions. Add idempotent schema safety tests or SQL validation. Do not claim remote deployment before a live schema query succeeds.
4. **Offline and media behavior:** cache user library/favorites/history where useful, exercise background audio integration on device, and implement native platform channel behavior on each claimed platform.
5. **Quality gate:** add focused unit/widget/integration tests; measure coverage and continue until the course threshold (>40%) is met. Keep CI green and run Android/web builds where possible.
6. **Release and course evidence:** configure release signing by secret-backed Gradle properties, prepare store metadata/privacy package and demo/profiling checklist. Do not upload or publish without account access.
7. **Docs:** reconcile every row of `README.md` and `docs/DEVELOPMENT_STATUS.md` against executable evidence, marking external deliverables as owner actions.

## Review focus

- Anonymous catalog requests before schema deployment: show cache plus a useful backend/setup message.
- RLS denial on private playlists: do not lose public catalog results.
- Location denied or services disabled: retain a screen with a retry path and explanatory text.
- Slow/failed audio load or track changes: keep playback state and visible controls consistent.
- Release build without public Supabase configuration or signing values: fail early with an actionable message and never fall back to a dummy endpoint.

## External completion gates

- A Supabase CLI session or database password is needed to apply and verify remote SQL migrations.
- A restricted Google Maps Android/iOS API key and real venue catalog are needed to verify map tiles and venue details.
- Google OAuth client configuration, notification provider credentials, crash-report project configuration, signing keystore, and Play Console access are owner-controlled.
- A physical Android device or complete emulator/NDK installation is required for native sensor, background audio, integration, and release verification.
