#!/usr/bin/env bash
# Sync edge proxy: /opt/miru-infra/edge → ~/miru-edge (user deploy; /opt tidak bisa ditulis tanpa sudo) (aman dijalankan ulang).
#
# - Jaringan `miru-edge` dibuat bila belum ada (dipakai stack staging & prod).
# - Sertifikat dibaca nginx lewat symlink stabil certs/current/{staging,production}.
#   Pertama kali: current/staging → salinan sertifikat staging lama (bootstrap)
#   sampai scripts/edge-certs.sh menerbitkan sertifikat webroot.
# - production.conf hanya diaktifkan bila current/production sudah ada.
set -euo pipefail

INFRA="${INFRA_DIR:-/opt/miru-infra}"
EDGE="${EDGE_DIR:-$HOME/miru-edge}"
LEGACY_STAGING_CERT=/opt/miru-staging/certs/live/dev.mirubanksampah.id

mkdir -p "$EDGE/conf.d" "$EDGE/certs/current" "$EDGE/webroot"
docker network inspect miru-edge >/dev/null 2>&1 || docker network create miru-edge

if [ ! -e "$EDGE/certs/current/staging/fullchain.pem" ]; then
  mkdir -p "$EDGE/certs/bootstrap/staging"
  cp -L "$LEGACY_STAGING_CERT/fullchain.pem" "$LEGACY_STAGING_CERT/privkey.pem" \
    "$EDGE/certs/bootstrap/staging/"
  chmod 600 "$EDGE/certs/bootstrap/staging/privkey.pem"
  ln -sfn ../bootstrap/staging "$EDGE/certs/current/staging"
  echo "Bootstrap: current/staging → salinan sertifikat staging lama."
fi

cp "$INFRA/edge/docker-compose.yml" "$EDGE/"
rm -f "$EDGE/conf.d/"*.conf
cp "$INFRA/edge/conf.d/"*.conf "$EDGE/conf.d/"
if [ -e "$EDGE/certs/current/production/fullchain.pem" ]; then
  cp "$INFRA/edge/production.conf" "$EDGE/conf.d/20-production.conf"
  echo "Production aktif di edge."
else
  echo "Production belum aktif (sertifikat belum ada: scripts/edge-certs.sh production)."
fi

cd "$EDGE"
docker compose up -d
# Konfigurasi baru: uji dulu, baru reload (gagal uji → nginx lama tetap jalan).
docker compose exec -T nginx nginx -t
docker compose exec -T nginx nginx -s reload
docker compose ps
