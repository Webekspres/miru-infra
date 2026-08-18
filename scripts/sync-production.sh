#!/usr/bin/env bash
# Sync production stack: /opt/miru-infra → /opt/miru-prod
set -euo pipefail

INFRA="${INFRA_DIR:-/opt/miru-infra}"
TARGET="${TARGET_DIR:-/opt/miru-prod}"

cp "$INFRA/production/docker-compose.yml" "$TARGET/"
cp "$INFRA/production/nginx.conf" "$TARGET/"

cd "$TARGET"
docker compose up -d
if docker compose ps nginx --status running >/dev/null 2>&1; then
  docker compose exec -T nginx nginx -t
  docker compose exec -T nginx nginx -s reload
fi
docker compose ps
