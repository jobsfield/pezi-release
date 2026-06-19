#!/bin/bash

set -euo pipefail

fail() {
  echo "error: $*" >&2
  exit 1
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PUBLISH_SCRIPT="$SCRIPT_DIR/publish-release.sh"

[[ -x "$PUBLISH_SCRIPT" ]] || fail "Missing publish script at $PUBLISH_SCRIPT"

find_latest_app() {
  python3 - <<'PY'
from pathlib import Path
import sys

archives_root = Path.home() / "Library/Developer/Xcode/Archives"
if not archives_root.exists():
    sys.exit(1)

candidates = []
for path in archives_root.glob("**/Products/Applications/Pezi.app"):
    try:
        stat = path.stat()
    except FileNotFoundError:
        continue
    candidates.append((stat.st_mtime, str(path)))

if not candidates:
    sys.exit(1)

candidates.sort(reverse=True)
print(candidates[0][1])
PY
}

detect_release_notes() {
  local app_path="$1"
  local info_plist="$app_path/Contents/Info.plist"
  local short_version build_version

  short_version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$info_plist" 2>/dev/null || true)
  build_version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$info_plist" 2>/dev/null || true)

  [[ -n "$short_version" ]] || return 1
  [[ -n "$build_version" ]] || return 1

  local release_notes_dir="$REPO_ROOT/release-notes"
  [[ -d "$release_notes_dir" ]] || return 1

  local candidates=(
    "$release_notes_dir/${short_version}-${build_version}.md"
    "$release_notes_dir/${short_version}.md"
    "$release_notes_dir/${build_version}.md"
    "$release_notes_dir/latest.md"
  )

  local candidate
  for candidate in "${candidates[@]}"; do
    if [[ -f "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

APP_PATH="$(find_latest_app)" || fail "Could not find a Pezi.app archive under ~/Library/Developer/Xcode/Archives. Build, sign, and notarize the app in Xcode first."
RELEASE_NOTES=""

if RELEASE_NOTES="$(detect_release_notes "$APP_PATH")"; then
  echo "Using release notes: $RELEASE_NOTES"
else
  RELEASE_NOTES=""
fi

echo "Using latest archived app: $APP_PATH"

cmd=( "$PUBLISH_SCRIPT" --app "$APP_PATH" --commit --push )
if [[ -n "$RELEASE_NOTES" ]]; then
  cmd+=( --release-notes "$RELEASE_NOTES" )
fi

"${cmd[@]}"
