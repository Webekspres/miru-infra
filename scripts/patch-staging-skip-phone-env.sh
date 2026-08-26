#!/usr/bin/env bash
# Patch /opt/miru-staging/.env untuk bypass verifikasi WA (internal testing).
# Jalankan di VPS setelah merge dev→staging: bash patch-staging-skip-phone-env.sh
set -euo pipefail

ENV_FILE="${ENV_FILE:-/opt/miru-staging/.env}"
COMPOSE_DIR="${COMPOSE_DIR:-/opt/miru-staging}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: $ENV_FILE tidak ditemukan" >&2
  exit 1
fi

patch_kv() {
  local key="$1" val="$2"
  if grep -q "^${key}=" "$ENV_FILE"; then
    sed -i "s|^${key}=.*|${key}=${val}|" "$ENV_FILE"
  else
    echo "${key}=${val}" >> "$ENV_FILE"
  fi
}

patch_kv DEBUG False
patch_kv SKIP_PHONE_VERIFICATION True

echo "==> .env (non-secret keys):"
grep -E '^(DEBUG|SKIP_PHONE|OTP_DEV)=' "$ENV_FILE" || true

cd "$COMPOSE_DIR"
echo "==> Pull & restart API..."
docker compose pull api
docker compose up -d --no-deps api

echo "==> Django settings (runtime):"
docker compose exec -T api python -c \
  "from django.conf import settings; print('DEBUG=', settings.DEBUG, 'SKIP_PHONE_VERIFICATION=', settings.SKIP_PHONE_VERIFICATION)"

echo "==> Selesai. Request OTP di mobile akan auto-verifikasi HP."
