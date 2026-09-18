#!/usr/bin/env bash
# Sync staging stack: /opt/miru-infra → /opt/miru-staging
set -euo pipefail

INFRA="${INFRA_DIR:-/opt/miru-infra}"
TARGET="${TARGET_DIR:-/opt/miru-staging}"

cp "$INFRA/staging/docker-compose.yml" "$TARGET/"
cp "$INFRA/staging/nginx.conf" "$TARGET/"

cd "$TARGET"

# Infra owns the shared services (db, minio, nginx) whose images are public
# and always pullable. The application images (api, admin) live in per-repo
# GHCR packages that this workflow's GITHUB_TOKEN cannot pull cross-repo, and
# they are already published+deployed by their own CI/CD pipelines. So we only
# bring up infra-owned services here and reload nginx — a blanket
# `docker compose up -d` would try to (re)pull api/admin and fail with
# "denied". api/admin pick up any compose changes on their next app deploy.
docker compose up -d db minio minio-init

# Apply the freshly-copied nginx.conf without recreating the app services.
docker compose up -d --no-deps --force-recreate nginx

docker compose ps
