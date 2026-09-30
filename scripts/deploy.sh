#!/usr/bin/env bash
# Terapkan infra satu environment di VPS (dipanggil GitHub Actions setelah
# /opt/miru-infra ditarik ke branch main).
#
#   scripts/deploy.sh staging      # /opt/miru-staging (+ proxy edge)
#   scripts/deploy.sh production   # /opt/miru-prod    (+ proxy edge)
set -euo pipefail

INFRA="$(cd "$(dirname "$0")/.." && pwd)"
case "${1:-}" in
  staging) TARGET=/opt/miru-staging; SYNC=sync-staging.sh ;;
  production) TARGET=/opt/miru-prod; SYNC=sync-production.sh ;;
  *) echo "Pemakaian: $0 staging|production" >&2; exit 1 ;;
esac

if [ ! -d "$TARGET" ]; then
  echo "ERROR: $TARGET belum ada. Jalankan sekali (butuh sudo):"
  echo "  sudo mkdir -p $TARGET && sudo chown -R developer:developer $TARGET"
  exit 1
fi

cd "$TARGET"
touch .env
if [ "$1" = staging ]; then
  # Default staging — hanya diisi bila belum ada (tidak menimpa nilai operator).
  grep -q '^MINIO_ROOT_USER=' .env || echo 'MINIO_ROOT_USER=miru_staging' >> .env
  grep -q '^MINIO_ROOT_PASSWORD=' .env || echo "MINIO_ROOT_PASSWORD=$(openssl rand -hex 16)" >> .env
  grep -q '^MINIO_ACCESS_KEY=' .env || echo 'MINIO_ACCESS_KEY=miru_staging' >> .env
  grep -q '^MINIO_SECRET_KEY=' .env || echo "MINIO_SECRET_KEY=$(grep '^MINIO_ROOT_PASSWORD=' .env | cut -d= -f2-)" >> .env
  grep -q '^MINIO_BUCKET=' .env || echo 'MINIO_BUCKET=mirubanksampah' >> .env
  grep -q '^MINIO_REGION=' .env || echo 'MINIO_REGION=us-east-1' >> .env
  grep -q '^COOKIE_DOMAIN=' .env || echo 'COOKIE_DOMAIN=dev.mirubanksampah.id' >> .env
fi

INFRA_DIR="$INFRA" bash "$INFRA/scripts/$SYNC"

for i in $(seq 1 30); do
  if docker compose ps minio 2>/dev/null | grep -q '(healthy)'; then
    echo "MinIO sehat."
    break
  fi
  [ "$i" -eq 30 ] && { echo "MinIO tidak sehat." >&2; exit 1; }
  sleep 2
done

# API bisa belum ada (deploy pertama sebelum pipeline aplikasi) — lewati cek.
if [ -n "$(docker compose ps -q api 2>/dev/null)" ]; then
  docker compose exec -T api python manage.py shell -c "
from django.conf import settings
from api.services.object_storage import ensure_bucket
assert settings.MINIO_ENABLED
ensure_bucket()
print('MinIO OK:', settings.MINIO_ENDPOINT, settings.MINIO_BUCKET)
"
fi
docker compose ps
echo "==> Infra $1 selesai."
