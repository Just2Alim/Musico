#!/usr/bin/env bash
set -euo pipefail

config_file=".env.local"
if [[ ! -f "$config_file" ]]; then
  echo "Missing $config_file. Copy .env.example to .env.local and fill in the public Supabase values." >&2
  exit 1
fi
set -a
source "$config_file"
set +a
: "${SUPABASE_URL:?SUPABASE_URL is required}"
: "${SUPABASE_PUBLISHABLE_KEY:?SUPABASE_PUBLISHABLE_KEY is required}"
flutter_args=(
  --dart-define="SUPABASE_URL=$SUPABASE_URL"
  --dart-define="SUPABASE_PUBLISHABLE_KEY=$SUPABASE_PUBLISHABLE_KEY"
)
if [[ -n "${JAMENDO_CLIENT_ID:-}" ]]; then
  flutter_args+=(--dart-define="JAMENDO_CLIENT_ID=$JAMENDO_CLIENT_ID")
fi
if [[ -n "${GOOGLE_MAPS_API_KEY:-}" ]]; then
  flutter_args+=(--dart-define="GOOGLE_MAPS_API_KEY=$GOOGLE_MAPS_API_KEY")
  printf 'GOOGLE_MAPS_API_KEY = %s\n' "$GOOGLE_MAPS_API_KEY" > ios/Flutter/Local.xcconfig
fi
exec flutter run "${flutter_args[@]}" "$@"
