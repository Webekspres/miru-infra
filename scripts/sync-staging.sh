#!/usr/bin/env bash
# Sync staging stack from cloned repo to runtime dir on VPS.
# Usage (on VPS): bash ~/miru-infra/scripts/sync-staging.sh
set -euo pipefail

INFRA="${INFRA_DIR:-$HOME/miru-infra}"
TARGET="${TARGET_DIR:-/opt/miru-staging}"

cp "$INFRA/staging/docker-compose.yml" "$TARGET/"
cp "$INFRA/staging/nginx.conf" "$TARGET/"

cd "$TARGET"
docker compose up -d
docker compose ps
