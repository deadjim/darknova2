#!/usr/bin/env bash
# Deploy Dark Nova ][ web build to the VPS (2.darknova.org).
# --pwa-strategy=none: no offline service worker — playtest builds must
# always be fresh. web/flutter_service_worker.js is a kill-switch that
# cleans up clients still holding the old offline-first worker.
set -euo pipefail
cd "$(dirname "$0")"

export PATH="$PATH:$HOME/flutter/bin"
flutter build web --release --pwa-strategy=none
# The flutter tool owns this filename and emits an empty stub even with
# --pwa-strategy=none; restore the kill-switch worker (old clients are
# registered at exactly this URL).
cp web/flutter_service_worker.js build/web/flutter_service_worker.js
rsync -az --delete build/web/ shon@45.77.127.32:~/darknova2-web/
ssh shon@45.77.127.32 'systemctl --user restart darknova2.service'
code=$(curl -s -o /dev/null -w "%{http_code}" https://2.darknova.org/)
echo "https://2.darknova.org → HTTP $code"
