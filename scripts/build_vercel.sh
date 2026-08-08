#!/usr/bin/env bash
set -euo pipefail

# Build the existing public/admin Vite site first.
npm --prefix admin_web install
npm --prefix admin_web run build

# Build the same Flutter application used on Android as the authenticated web
# app. Vercel images do not guarantee Flutter is installed, so cache a shallow
# stable SDK checkout when needed.
FLUTTER_DIR="${HOME}/.cache/prosme-flutter"
if ! command -v flutter >/dev/null 2>&1; then
  if [ ! -x "${FLUTTER_DIR}/bin/flutter" ]; then
    rm -rf "${FLUTTER_DIR}"
    git clone --depth 1 --branch stable https://github.com/flutter/flutter.git "${FLUTTER_DIR}"
  fi
  export PATH="${FLUTTER_DIR}/bin:${PATH}"
fi

if [ -z "${VITE_SUPABASE_PUBLISHABLE_KEY:-}" ] && [ -z "${SUPABASE_ANON_KEY:-}" ]; then
  echo "Missing VITE_SUPABASE_PUBLISHABLE_KEY or SUPABASE_ANON_KEY" >&2
  exit 1
fi

SUPABASE_URL_VALUE="${VITE_SUPABASE_URL:-${SUPABASE_URL:-https://wbnvifrzckjttyxhmlcf.supabase.co}}"
SUPABASE_KEY_VALUE="${VITE_SUPABASE_PUBLISHABLE_KEY:-${SUPABASE_ANON_KEY:-}}"

flutter config --enable-web >/dev/null
flutter pub get
flutter build web \
  --release \
  --base-href /app/ \
  --dart-define="SUPABASE_URL=${SUPABASE_URL_VALUE}" \
  --dart-define="SUPABASE_ANON_KEY=${SUPABASE_KEY_VALUE}" \
  --dart-define="PASSWORD_RECOVERY_REDIRECT_URL=https://prosme.blumebyte.com/reset-password" \
  --dart-define="EMAIL_VERIFICATION_REDIRECT_URL=https://prosme.blumebyte.com/auth"

rm -rf admin_web/dist/app
mkdir -p admin_web/dist/app
cp -R build/web/. admin_web/dist/app/
