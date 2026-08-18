#!/usr/bin/env bash
# Sync staging stack: /opt/miru-infra → /opt/miru-staging
set -euo pipefail

INFRA="${INFRA_DIR:-/opt/miru-infra}"
TARGET="${TARGET_DIR:-/opt/miru-staging}"

cp "$INFRA/staging/docker-compose.yml" "$TARGET/"
cp "$INFRA/staging/nginx.conf" "$TARGET/"

cd "$TARGET"
docker compose up -d
docker compose ps
