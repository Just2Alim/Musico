#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ -f .env.local ]]; then
  set -a
  source .env.local
  set +a
fi
: "${SUPABASE_URL:?Set SUPABASE_URL in .env.local}"
: "${SUPABASE_PUBLISHABLE_KEY:?Set SUPABASE_PUBLISHABLE_KEY in .env.local}"
exec flutter test integration_test/app_flow_test.dart \
  -d "${1:-emulator-5554}" --no-pub \
  --dart-define="SUPABASE_URL=$SUPABASE_URL" \
  --dart-define="SUPABASE_PUBLISHABLE_KEY=$SUPABASE_PUBLISHABLE_KEY"
