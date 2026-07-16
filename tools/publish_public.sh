#!/usr/bin/env bash
# Publish the current private main to the public repo, minus proprietary assets.
#
# The public repo (github.com/deadjim/darknova2) is a curated snapshot mirror:
# each run adds ONE commit on top of its existing history whose tree is the
# private HEAD's tracked files with EXCLUDES stripped. Never push to the
# public repo directly — this script is the only sync path.
set -euo pipefail

PUB_URL=https://github.com/deadjim/darknova2.git
EXCLUDES=(assets)   # paths stripped from the public tree (repo-root-relative)

ROOT=$(git rev-parse --show-toplevel)
MIRROR=$ROOT/.public-mirror
SHA=$(git -C "$ROOT" rev-parse --short HEAD)
SUBJECT=$(git -C "$ROOT" log -1 --format=%s)

if [[ -n $(git -C "$ROOT" status --porcelain) ]]; then
  echo "Working tree not clean — commit or stash first." >&2
  exit 1
fi

# Fresh-or-updated clone of the public repo
if [[ -d $MIRROR/.git ]]; then
  git -C "$MIRROR" fetch origin main
  git -C "$MIRROR" reset --hard origin/main
else
  git clone "$PUB_URL" "$MIRROR"
fi

# Export tracked files of HEAD (git archive ignores untracked/ignored junk)
EXPORT=$(mktemp -d)
trap 'rm -rf "$EXPORT"' EXIT
git -C "$ROOT" archive HEAD | tar -x -C "$EXPORT"
for path in "${EXCLUDES[@]}"; do
  rm -rf "${EXPORT:?}/$path"
done

rsync -a --delete --exclude=.git "$EXPORT"/ "$MIRROR"/

git -C "$MIRROR" add -A
if git -C "$MIRROR" diff --cached --quiet; then
  echo "Public repo already up to date with private $SHA — nothing to publish."
  exit 0
fi
git -C "$MIRROR" commit -m "Sync from private $SHA: $SUBJECT"
git -C "$MIRROR" push origin main
echo "Published private $SHA to $PUB_URL"
