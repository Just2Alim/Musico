# Musico Design, OAuth, and Licensed Catalog Implementation Plan

> **For agentic workers:** The user directly requested implementation, verification, and publication to the named GitHub repository; proceed with the native workflow and preserve the current branch/history.

**Goal:** Give Musico a consistent streaming-app interface, verify and complete its Google sign-in path as far as available credentials allow, and prepare a legally sourced online catalog integration.

**Architecture:** Establish a shared Material 3 dark visual system with reusable page headers, surfaces, buttons, spacing, and typography, then migrate the existing screens to it without changing their data flows. Keep Supabase Auth and the existing catalog as the source of truth; add any external catalog as an opt-in adapter that uses its own public API credentials and preserves attribution/licence data.

**Tech Stack:** Flutter/Dart, Material 3, Provider, Supabase Flutter, existing HTTP client, Jamendo API (optional client ID), Flutter tests, Android emulator, Git.

**Spec:** User request on 2026-10-15; coursework criteria in `individual_project_flutter_ru.docx`; existing repository guidance in `AGENTS.md`.

## Global Constraints

- Keep Musico as the app identity; use familiar streaming-app patterns without copying Spotify logos, artwork, or proprietary assets.
- Never place Supabase secret/service-role keys or OAuth client secrets in Flutter, tests, or committed files.
- Only stream tracks from sources whose API/license permits the app's use; do not promise the complete commercial catalog of all performers.
- Maintain Android, web, and accessibility behavior; preserve the active Supabase account and existing data.
- Run the requested checks and only push changes after inspecting the exact staged diff.

## Review Focus

- Theme changes must cover auth, shell, search, player, playlist, account, notifications, and venues consistently; add widget assertions for shared colors/components.
- OAuth must fail with a clear configuration message when Google is disabled or redirects are not allow-listed; verify actual provider state and deep link before claiming end-to-end login.
- External track IDs and missing license/art fields must not collide with Supabase IDs or create uncredited/unplayable tracks; add serialization/adapter tests.
- Credential scans must prove no private keys, `.env.local`, user passwords, or commercial audio files enter the commit.
- Verify release build/test state before commit and confirm the destination branch before push.

---

### Task 1: Establish shared design tokens and components

**Files:** Modify `lib/themes/app_theme.dart`; create focused shared theme widgets under `lib/widgets/`; test in `test/themes/` and `test/widgets/`.

- [ ] Define semantic colors, text styles, input/button/card themes, page background, and spacing/radius tokens.
- [ ] Add tests asserting the app's dark Material 3 scheme and component defaults.
- [ ] Run focused tests, then migrate screens in Task 2.

### Task 2: Unify the page experience

**Files:** `lib/features/navigation/main_navigation_shell.dart`, `lib/screens/{home_screen,search_screen,library_screen,account_screen,login_screen,register_screen,playlist_screen}.dart`, `lib/services/{player_screen,detailed_playlist_screen,library_screen,search_screen}.dart`, `lib/features/{notifications/notifications_screen,venues/venues_screen}.dart`, focused widget tests.

- [ ] Inventory page colors, headers, spacing, selected states, loading/error/empty views.
- [ ] Add/extend widget tests for shared navigation, headers, cards, fields, and dialogs.
- [ ] Replace page-local styling with shared tokens/components and correct inconsistent English copy to the app's existing locale strategy.
- [ ] Run relevant widget tests and inspect the Android emulator at phone width.

### Task 3: Verify Google OAuth configuration and callback

**Files:** `lib/data/supabase_config.dart`, `lib/screens/login_screen.dart`, Android/iOS deep-link configuration, `.env.example`, Auth tests, `docs/DEVELOPMENT_STATUS.md`.

- [ ] Check the public Supabase Auth settings and local redirect values without printing credentials.
- [ ] Add tests for missing provider/configuration behavior and the redirect URI used by native OAuth.
- [ ] Align Android intent filter and iOS URL scheme with the configured redirect; keep web redirect separate.
- [ ] Trigger the flow on the emulator only if the remote provider is enabled; stop for user handoff at Google's credential prompt.
- [ ] Report any missing Supabase/Google Cloud client configuration explicitly.

### Task 4: Provide an optional licensed catalog adapter

**Files:** Create `lib/data/jamendo_catalog_service.dart`; update `Track` mapping/credit UI as needed, `.env.example`, app wiring, tests, and `docs/MUSIC_SOURCES.md`.

- [ ] Add failing tests for Jamendo response mapping, absent/invalid client ID, attribution, and stream URLs.
- [ ] Implement a paginated/searchable adapter using the existing HTTP dependency and an optional `JAMENDO_CLIENT_ID`.
- [ ] Keep API credentials out of the Supabase schema and source code; if the client ID is not configured, retain the current licensed catalog and show a clear setup note.
- [ ] Test the configured API only when a client ID exists; document the catalog's scope and terms accurately.

### Task 5: Final verification and GitHub publication

**Files:** Update `README.md`, `docs/DEVELOPMENT_STATUS.md`, catalog/design docs; stage only reviewed project changes.

- [ ] Run Dart format, Flutter analyze, the full test suite, coverage gate, and Android build/smoke checks when available.
- [ ] Inspect staged diff and scan tracked candidates for secrets, ignored env files, and copyrighted media.
- [ ] Commit with a conventional message and push to `origin/main` as requested.
- [ ] Verify remote commit hash and report any provider/account configuration that still requires owner action.
