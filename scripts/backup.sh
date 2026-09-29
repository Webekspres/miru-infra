#!/usr/bin/env bash
# Backup terenkripsi (GPG AES-256) database Postgres + objek MinIO satu stack.
#
#   scripts/backup.sh production            jalankan backup sekarang
#   scripts/backup.sh staging
#   scripts/backup.sh production install-cron   harian 02.00 waktu server
#
# Hasil: ~/miru-backups/<env>/daily/<env>_<waktu>_{db.dump,minio.tar.gz}.gpg
#   - harian disimpan 14 hari; backup hari Minggu disalin ke weekly/ (90 hari)
#   - dump DB diverifikasi (dekripsi + pg_restore --list) setiap kali backup
# Passphrase: ~/miru-backups/.passphrase (dibuat sekali, izin 600). SIMPAN
# SALINANNYA DI LUAR VPS — tanpa passphrase backup tidak bisa dipulihkan.
#
# Pulihkan DB (contoh):
#   gpg -d --batch --pinentry-mode loopback --passphrase-file ~/miru-backups/.passphrase FILE_db.dump.gpg \
#     | docker compose -f /opt/miru-prod/docker-compose.yml exec -T db pg_restore -U miru -d miru_prod --clean --if-exists
set -euo pipefail

ENV_NAME="${1:-}"
case "$ENV_NAME" in
  staging) DIR=/opt/miru-staging ;;
  production) DIR=/opt/miru-prod ;;
  *) echo "Pemakaian: $0 staging|production [install-cron]" >&2; exit 1 ;;
esac

ROOT="${BACKUP_ROOT:-$HOME/miru-backups}"
PASSFILE="$ROOT/.passphrase"
OUT="$ROOT/$ENV_NAME"
SELF="$(readlink -f "$0")"

if [ "${2:-}" = "install-cron" ]; then
  MARK="# miru-$ENV_NAME backup"
  LINE="0 2 * * * bash $SELF $ENV_NAME >> $OUT/backup.log 2>&1 $MARK"
  mkdir -p "$OUT"
  { { crontab -l 2>/dev/null || true; } | grep -vF "$MARK" || true; echo "$LINE"; } | crontab -
  crontab -l | grep -F "$MARK"
  exit 0
fi

umask 077
mkdir -p "$OUT/daily" "$OUT/weekly"
if [ ! -s "$PASSFILE" ]; then
  head -c 48 /dev/urandom | base64 | tr -d '\n' > "$PASSFILE"
  echo "Passphrase baru dibuat di $PASSFILE — salin ke tempat aman di luar VPS."
fi

encrypt() {
  gpg --batch --yes --pinentry-mode loopback --passphrase-file "$PASSFILE" \
    --symmetric --cipher-algo AES256 -o "$1"
}
decrypt() {
  gpg --batch --quiet --pinentry-mode loopback --passphrase-file "$PASSFILE" -d "$1"
}

envval() { grep -E "^$1=" "$DIR/.env" | tail -1 | cut -d= -f2-; }
DB_USER="$(envval DB_USER)"
DB_NAME="$(envval DB_NAME)"
STAMP="$(date +%Y-%m-%d_%H%M)"
DB_FILE="$OUT/daily/${ENV_NAME}_${STAMP}_db.dump.gpg"
MINIO_FILE="$OUT/daily/${ENV_NAME}_${STAMP}_minio.tar.gz.gpg"
compose() { docker compose -f "$DIR/docker-compose.yml" --project-directory "$DIR" "$@"; }

echo "[$(date '+%F %T')] Backup $ENV_NAME dimulai"

compose exec -T db pg_dump -U "$DB_USER" -d "$DB_NAME" --format=custom | encrypt "$DB_FILE"
# Verifikasi: bisa didekripsi dan dibaca pg_restore.
TABLES="$(decrypt "$DB_FILE" | compose exec -T db pg_restore --list | grep -c ' TABLE ' || true)"
[ "$TABLES" -gt 0 ] || { echo "GAGAL verifikasi dump DB" >&2; rm -f "$DB_FILE"; exit 1; }

MINIO_CONTAINER="$(compose ps -q minio)"
docker run --rm --volumes-from "$MINIO_CONTAINER":ro alpine \
  tar czf - -C /data . | encrypt "$MINIO_FILE"

if [ "$(date +%u)" = "7" ]; then
  cp "$DB_FILE" "$MINIO_FILE" "$OUT/weekly/"
fi
find "$OUT/daily" -name '*.gpg' -mtime +14 -delete
find "$OUT/weekly" -name '*.gpg' -mtime +90 -delete

echo "[$(date '+%F %T')] OK: $(du -h "$DB_FILE" | cut -f1) DB ($TABLES tabel), $(du -h "$MINIO_FILE" | cut -f1) MinIO; total $(du -sh "$OUT" | cut -f1)"
