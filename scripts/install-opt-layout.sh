#!/usr/bin/env bash
# One-time VPS setup: clone miru-infra to /opt and remove ~/miru-infra legacy path.
set -euo pipefail

REPO="${REPO_URL:-https://github.com/Webekspres/miru-infra.git}"
BRANCH="${BRANCH:-staging}"
OPT_INFRA="/opt/miru-infra"
HOME_INFRA="$HOME/miru-infra"

sudo mkdir -p /opt/miru-staging /opt/miru-prod "$OPT_INFRA"
sudo chown -R developer:developer /opt/miru-staging /opt/miru-prod "$OPT_INFRA"

if [ -d "$HOME_INFRA/.git" ] && [ ! -d "$OPT_INFRA/.git" ]; then
  echo "==> Moving $HOME_INFRA -> $OPT_INFRA"
  mv "$HOME_INFRA" "$OPT_INFRA"
elif [ ! -d "$OPT_INFRA/.git" ]; then
  echo "==> Cloning $REPO -> $OPT_INFRA"
  git clone --branch "$BRANCH" "$REPO" "$OPT_INFRA"
else
  echo "==> Updating $OPT_INFRA"
  cd "$OPT_INFRA"
  git fetch origin
  git checkout "$BRANCH"
  git pull origin "$BRANCH"
fi

rm -rf "$HOME_INFRA" 2>/dev/null || true

echo "==> /opt layout:"
ls -la /opt/ | grep miru || true
echo "Done. Run: bash $OPT_INFRA/scripts/sync-staging.sh"
