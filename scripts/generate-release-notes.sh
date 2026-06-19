#!/bin/bash

set -euo pipefail

fail() {
  echo "error: $*" >&2
  exit 1
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

APP_PATH=""
APP_REPO=""
OUTPUT_PATH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app)
      APP_PATH="${2:-}"
      shift 2
      ;;
    --app-repo)
      APP_REPO="${2:-}"
      shift 2
      ;;
    --output)
      OUTPUT_PATH="${2:-}"
      shift 2
      ;;
    *)
      fail "Unknown argument: $1"
      ;;
  esac
done

[[ -n "$APP_PATH" ]] || fail "--app is required"
[[ -d "$APP_PATH" ]] || fail "App bundle not found: $APP_PATH"

INFO_PLIST="$APP_PATH/Contents/Info.plist"
[[ -f "$INFO_PLIST" ]] || fail "Missing Info.plist in app bundle: $INFO_PLIST"

SHORT_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO_PLIST" 2>/dev/null || true)
BUILD_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$INFO_PLIST" 2>/dev/null || true)

[[ -n "$SHORT_VERSION" ]] || fail "CFBundleShortVersionString is missing from the app bundle"
[[ -n "$BUILD_VERSION" ]] || fail "CFBundleVersion is missing from the app bundle"

if [[ -z "$APP_REPO" ]]; then
  DEFAULT_APP_REPO="$(cd "$REPO_ROOT/.." && pwd)/candy-jar"
  if [[ -d "$DEFAULT_APP_REPO/.git" ]]; then
    APP_REPO="$DEFAULT_APP_REPO"
  fi
fi

RELEASE_NOTES_DIR="$REPO_ROOT/release-notes"
mkdir -p "$RELEASE_NOTES_DIR"

if [[ -z "$OUTPUT_PATH" ]]; then
  OUTPUT_PATH="$RELEASE_NOTES_DIR/${SHORT_VERSION}-${BUILD_VERSION}.md"
fi

if [[ -f "$OUTPUT_PATH" ]]; then
  printf '%s\n' "$OUTPUT_PATH"
  exit 0
fi

COMMITS=""
if [[ -n "$APP_REPO" && -d "$APP_REPO/.git" ]]; then
  COMMITS="$(git -C "$APP_REPO" log --no-merges -n 5 --pretty=format:'%s' -- HiveContainerBrowser 2>/dev/null || true)"
  if [[ -z "$COMMITS" ]]; then
    COMMITS="$(git -C "$APP_REPO" log --no-merges -n 5 --pretty=format:'%s' 2>/dev/null || true)"
  fi
fi

{
  echo "# Pezi ${SHORT_VERSION}"
  echo
  echo "Build ${BUILD_VERSION}"
  echo
  if [[ -n "$COMMITS" ]]; then
    echo "Highlights:"
    while IFS= read -r line; do
      [[ -n "$line" ]] || continue
      echo "- $line"
    done <<< "$COMMITS"
  else
    echo "Highlights:"
    echo "- Automated release for Pezi ${SHORT_VERSION} (build ${BUILD_VERSION})"
  fi
} > "$OUTPUT_PATH"

printf '%s\n' "$OUTPUT_PATH"
