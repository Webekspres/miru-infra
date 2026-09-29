#!/usr/bin/env bash
# Sync production stack: /opt/miru-infra → /opt/miru-prod, lalu edge proxy.
set -euo pipefail

INFRA="${INFRA_DIR:-/opt/miru-infra}"
TARGET="${TARGET_DIR:-/opt/miru-prod}"

cp "$INFRA/production/docker-compose.yml" "$TARGET/"
rm -f "$TARGET/nginx.conf"  # nginx per-stack diganti edge proxy

cd "$TARGET"
docker network inspect miru-edge >/dev/null 2>&1 || docker network create miru-edge

# Infra memegang layanan ber-image publik (db, minio). Image aplikasi (api,
# admin) ada di GHCR per repo yang tidak bisa di-pull token workflow ini —
# dideploy pipeline masing-masing. --remove-orphans melepas nginx lama stack
# ini (port 80/443 kini dipegang edge proxy).
docker compose up -d --remove-orphans db minio minio-init

# api/admin bergabung ke jaringan miru-edge memakai image yang sudah ada di
# server (tanpa pull). Belum ada image → tunggu deploy CI aplikasi.
docker compose up -d --no-deps --pull never api admin \
  || echo "api/admin belum punya image di server — akan naik saat deploy CI."

bash "$INFRA/scripts/sync-edge.sh"
docker compose ps
