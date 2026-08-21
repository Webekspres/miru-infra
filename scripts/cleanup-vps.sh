#!/usr/bin/env bash
# Rapikan layout VPS — hapus folder legacy, pertahankan runtime yang dipakai.
# Usage: bash /opt/miru-infra/scripts/cleanup-vps.sh
set -euo pipefail

STAGING="/opt/miru-staging"
PROD="/opt/miru-prod"
LEGACY="/opt/miru"
INFRA="/opt/miru-infra"

echo "==> Hapus /opt/miru (legacy kosong dari setup awal Jul 28)"
if [ -d "$LEGACY" ]; then
  if [ -z "$(find "$LEGACY" -mindepth 1 -not -path '*/\.*' 2>/dev/null | head -1)" ]; then
    sudo rm -rf "$LEGACY"
    echo "    removed empty $LEGACY"
  else
    echo "    SKIP: $LEGACY tidak kosong — cek manual: ls -laR $LEGACY"
  fi
fi

echo "==> Hapus legacy di $STAGING (rsync lama, tidak dipakai compose GHCR)"
for path in admin backend Caddyfile README.md; do
  if [ -e "$STAGING/$path" ]; then
    rm -rf "$STAGING/$path"
    echo "    removed $STAGING/$path"
  fi
done

echo "==> Siapkan $PROD (runtime prod, kosong sampai go-live)"
sudo mkdir -p "$PROD/certs"
sudo chown -R developer:developer "$PROD"

echo "==> Re-sync compose dari infra"
bash "$INFRA/scripts/sync-staging.sh"

echo ""
echo "==> Layout akhir:"
ls -la /opt/ | grep miru || true
echo ""
echo "==> $STAGING (runtime — hanya file operasional):"
ls -la "$STAGING"
echo ""
echo "Done."
