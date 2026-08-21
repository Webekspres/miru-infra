#!/usr/bin/env bash
# One-time VPS setup: clone miru-infra to /opt and remove ~/miru-infra legacy path.
set -euo pipefail

REPO="${REPO_URL:-https://github.com/Webekspres/miru-infra.git}"
BRANCH="${BRANCH:-staging}"
OPT_INFRA="/opt/miru-infra"
HOME_INFRA="$HOME/miru-infra"

sudo mkdir -p /opt/miru-staging /opt/miru-prod
sudo chown -R developer:developer /opt/miru-staging /opt/miru-prod

# Fix botched mv: repo ended up at /opt/miru-infra/miru-infra/
if [ -d "$OPT_INFRA/miru-infra/.git" ] && [ ! -d "$OPT_INFRA/.git" ]; then
  echo "==> Fixing nested $OPT_INFRA/miru-infra -> $OPT_INFRA"
  rm -rf "$OPT_INFRA"/*
  mv "$OPT_INFRA/miru-infra"/* "$OPT_INFRA/"
  rmdir "$OPT_INFRA/miru-infra" 2>/dev/null || rm -rf "$OPT_INFRA/miru-infra"
fi

if [ -d "$HOME_INFRA/.git" ]; then
  if [ -d "$OPT_INFRA/.git" ]; then
    echo "==> $OPT_INFRA already has git; removing $HOME_INFRA"
    rm -rf "$HOME_INFRA"
  else
    echo "==> Moving $HOME_INFRA -> $OPT_INFRA"
    sudo rm -rf "$OPT_INFRA"
    sudo mv "$HOME_INFRA" "$OPT_INFRA"
    sudo chown -R developer:developer "$OPT_INFRA"
  fi
elif [ ! -d "$OPT_INFRA/.git" ]; then
  echo "==> Cloning $REPO -> $OPT_INFRA"
  sudo rm -rf "$OPT_INFRA"
  git clone --branch "$BRANCH" "$REPO" "$OPT_INFRA"
else
  echo "==> Updating $OPT_INFRA"
  cd "$OPT_INFRA"
  git fetch origin
  git checkout "$BRANCH"
  git pull origin "$BRANCH"
fi

rm -rf "$HOME_INFRA" 2>/dev/null || true
sudo chown -R developer:developer "$OPT_INFRA"

echo "==> /opt layout:"
ls -la /opt/ | grep miru || true
echo "Done. Run: bash $OPT_INFRA/scripts/sync-staging.sh"
