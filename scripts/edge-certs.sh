#!/usr/bin/env bash
# Sertifikat Let's Encrypt untuk edge proxy (mode webroot — nginx tetap jalan).
#
#   scripts/edge-certs.sh staging       dev.mirubanksampah.id, api.dev.mirubanksampah.id
#   scripts/edge-certs.sh production    mirubanksampah.id, www., api.
#   scripts/edge-certs.sh install-cron  perpanjangan otomatis harian (03.15)
#
# Berjalan sebagai user biasa: data certbot di ~/miru-edge/certs (config),
# bukan /etc/letsencrypt. Setelah terbit/diperpanjang, nginx di-reload.
set -euo pipefail

EDGE="${EDGE_DIR:-$HOME/miru-edge}"
EMAIL="${LE_EMAIL:-admin@mirubanksampah.id}"
CERTBOT_DIRS=(--config-dir "$EDGE/certs" --work-dir "$EDGE/.certbot/work" --logs-dir "$EDGE/.certbot/logs")
RELOAD="docker compose -f $EDGE/docker-compose.yml exec -T nginx nginx -s reload"

mkdir -p "$EDGE/.certbot/work" "$EDGE/.certbot/logs" "$EDGE/webroot"

issue() {
  local slot="$1" name="$2"; shift 2
  local domains=()
  for d in "$@"; do domains+=(-d "$d"); done
  certbot certonly --webroot -w "$EDGE/webroot" "${CERTBOT_DIRS[@]}" \
    --cert-name "$name" "${domains[@]}" \
    --non-interactive --agree-tos -m "$EMAIL" --key-type ecdsa \
    --deploy-hook "$RELOAD"
  ln -sfn "../live/$name" "$EDGE/certs/current/$slot"
  echo "current/$slot → live/$name"
}

case "${1:-}" in
  staging)
    issue staging miru-staging dev.mirubanksampah.id api.dev.mirubanksampah.id
    $RELOAD
    ;;
  production)
    issue production miru-prod mirubanksampah.id www.mirubanksampah.id api.mirubanksampah.id
    echo "Jalankan scripts/sync-edge.sh untuk mengaktifkan blok production."
    ;;
  install-cron)
    MARK="# miru-edge certbot renew"
    LINE="15 3 * * * certbot renew --quiet ${CERTBOT_DIRS[*]} >> $EDGE/.certbot/renew.log 2>&1 $MARK"
    { { crontab -l 2>/dev/null || true; } | grep -vF "$MARK" || true; echo "$LINE"; } | crontab -
    crontab -l | grep -F "$MARK"
    ;;
  *)
    echo "Pemakaian: $0 staging|production|install-cron" >&2
    exit 1
    ;;
esac
