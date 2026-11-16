#!/usr/bin/env bash
# Кладёт папку скриншотов в ветку ios-screens, НЕ стирая остальное (iOS-скриншоты, другие папки).
#   GH_TOKEN=… bash tool/ci/push_screens.sh shots/android android "Android emulator (API 34)"
set -eu
SRC=$1
DEST=$2
TITLE=${3:-$2}
REPO_URL="https://x-access-token:${GH_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"
WORK=$(mktemp -d)
for attempt in 1 2 3 4; do
  rm -rf "$WORK/b"
  if ! git clone -q --depth 1 -b ios-screens "$REPO_URL" "$WORK/b" 2>/dev/null; then
    mkdir -p "$WORK/b" && git -C "$WORK/b" init -q -b ios-screens
  fi
  rm -rf "${WORK:?}/b/$DEST"
  mkdir -p "$WORK/b/$DEST"
  cp "$SRC"/*.png "$WORK/b/$DEST/"
  {
    echo "# NutriMate — $TITLE"
    echo "Build ${GITHUB_SHA::7}, $(date -u '+%Y-%m-%d %H:%M UTC')."
    echo
    for f in "$WORK/b/$DEST"/*.png; do
      n=$(basename "$f")
      echo "### ${n%.png}"
      echo "<img src=\"$n\" width=\"300\">"
      echo
    done
  } > "$WORK/b/$DEST/README.md"
  cd "$WORK/b"
  git config user.name github-actions
  git config user.email github-actions@users.noreply.github.com
  git add -A "$DEST"
  git commit -qm "$DEST screens for ${GITHUB_SHA::7}" || { echo "nothing changed"; exit 0; }
  if git push -q "$REPO_URL" HEAD:ios-screens; then
    echo "pushed $DEST to ios-screens"
    exit 0
  fi
  cd - >/dev/null
  sleep $((attempt * 7))
done
echo "::warning::could not push screens to ios-screens"
