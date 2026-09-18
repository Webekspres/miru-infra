#!/usr/bin/env bash
# Sync production stack: /opt/miru-infra → /opt/miru-prod
set -euo pipefail

INFRA="${INFRA_DIR:-/opt/miru-infra}"
TARGET="${TARGET_DIR:-/opt/miru-prod}"

cp "$INFRA/production/docker-compose.yml" "$TARGET/"
cp "$INFRA/production/nginx.conf" "$TARGET/"

cd "$TARGET"

# Infra owns the shared services (db, minio, nginx) whose images are public.
# Application images (api, admin) live in per-repo GHCR packages that this
# workflow's GITHUB_TOKEN cannot pull cross-repo; they are deployed by their
# own CI/CD pipelines. Only bring up infra-owned services and reload nginx.
docker compose up -d db minio minio-init

docker compose up -d --no-deps --force-recreate nginx

docker compose ps
