#!/usr/bin/env bash
# Pasang cron harian MIRU untuk satu environment (aman dijalankan ulang).
#
#   scripts/install-cron.sh staging      # /opt/miru-staging
#   scripts/install-cron.sh production   # /opt/miru-prod
#
# Tugas: 02.30 waktu server — hapus pendaftaran nasabah yang tidak
# memverifikasi email dalam 24 jam (cleanup_unverified_accounts).
set -euo pipefail

case "${1:-}" in
  staging) DIR=/opt/miru-staging ;;
  production) DIR=/opt/miru-prod ;;
  *) echo "Pemakaian: $0 staging|production" >&2; exit 1 ;;
esac

MARK="# miru-$1 cleanup_unverified_accounts"
LOG="$DIR/logs/cron.log"
mkdir -p "$DIR/logs"

LINE="30 2 * * * cd $DIR && /usr/bin/docker compose exec -T api python manage.py cleanup_unverified_accounts >> $LOG 2>&1 $MARK"

# Ganti baris lama bertanda sama (idempoten), baris cron lain dibiarkan.
{ { crontab -l 2>/dev/null || true; } | grep -vF "$MARK" || true; echo "$LINE"; } | crontab -

echo "Cron terpasang:"
crontab -l | grep -F "$MARK"
