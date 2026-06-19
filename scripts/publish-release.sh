#!/bin/bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  publish-release.sh --app /path/to/Pezi.app [options]

Required:
  --app PATH                  Signed and notarized .app bundle to publish

Optional:
  --release-notes PATH        Markdown release notes to copy next to the zip
  --download-url-prefix URL   Public URL prefix for Pages assets
  --commit                    Commit generated release files in this repo
  --push                      Push this repo after committing
  --help                      Show this help

Behavior:
  1. Packages the .app with ditto into <AppName>.zip
  2. Regenerates appcast.xml with Sparkle's generate_appcast
  3. Optionally commits and pushes this Pages repo

Defaults:
  - The script publishes into the repo that contains the script
  - If --download-url-prefix is omitted, it is derived from SUFeedURL in the app's Info.plist

Example:
  ./scripts/publish-release.sh \
    --app "/Users/eason/Library/Developer/Xcode/Archives/2026-06-19/CandyJar 6-19-26, 2.52 PM.xcarchive/Products/Applications/Pezi.app" \
    --release-notes ./release-notes/1.0.1.md \
    --commit \
    --push
EOF
}

fail() {
  echo "error: $*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"
}

plist_read() {
  local plist_path="$1"
  local key="$2"
  /usr/libexec/PlistBuddy -c "Print :$key" "$plist_path" 2>/dev/null || true
}

ensure_trailing_slash() {
  case "$1" in
    */) printf '%s\n' "$1" ;;
    *) printf '%s/\n' "$1" ;;
  esac
}

appcast_contains_build() {
  local appcast_path="$1"
  local short_version="$2"
  local build_version="$3"

  [[ -f "$appcast_path" ]] || return 1

  python3 - "$appcast_path" "$short_version" "$build_version" <<'PY'
import sys
import xml.etree.ElementTree as ET

appcast_path, short_version, build_version = sys.argv[1:4]
ns = {"sparkle": "http://www.andymatuschak.org/xml-namespaces/sparkle"}

try:
    root = ET.parse(appcast_path).getroot()
except Exception:
    sys.exit(2)

for item in root.findall("./channel/item"):
    item_build = item.findtext("sparkle:version", namespaces=ns)
    item_short = item.findtext("sparkle:shortVersionString", namespaces=ns)
    if item_build == build_version or (item_build == build_version and item_short == short_version):
        sys.exit(0)

sys.exit(1)
PY
}

find_generate_appcast() {
  if [[ -n "${SPARKLE_GENERATE_APPCAST:-}" && -x "${SPARKLE_GENERATE_APPCAST}" ]]; then
    printf '%s\n' "${SPARKLE_GENERATE_APPCAST}"
    return 0
  fi

  if command -v generate_appcast >/dev/null 2>&1; then
    command -v generate_appcast
    return 0
  fi

  local candidate

  while IFS= read -r candidate; do
    if [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done < <(find "$HOME/Library/Developer/Xcode/DerivedData" -path '*/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_appcast' 2>/dev/null | sort -r)

  return 1
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_REPO="$(cd "$SCRIPT_DIR/.." && pwd)"

APP_PATH=""
RELEASE_NOTES=""
DOWNLOAD_URL_PREFIX=""
DO_COMMIT=0
DO_PUSH=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app)
      APP_PATH="${2:-}"
      shift 2
      ;;
    --release-notes)
      RELEASE_NOTES="${2:-}"
      shift 2
      ;;
    --download-url-prefix)
      DOWNLOAD_URL_PREFIX="${2:-}"
      shift 2
      ;;
    --commit)
      DO_COMMIT=1
      shift
      ;;
    --push)
      DO_PUSH=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      fail "Unknown argument: $1"
      ;;
  esac
done

require_command ditto
require_command git
require_command python3

[[ -n "$APP_PATH" ]] || fail "--app is required"
[[ -d "$APP_PATH" ]] || fail "App bundle not found: $APP_PATH"
[[ "$APP_PATH" == *.app ]] || fail "--app must point to a .app bundle"
[[ -d "$RELEASE_REPO/.git" ]] || fail "Script must live inside the Pages git repository"

if [[ -n "$RELEASE_NOTES" && ! -f "$RELEASE_NOTES" ]]; then
  fail "Release notes file not found: $RELEASE_NOTES"
fi

GENERATE_APPCAST="$(find_generate_appcast)" || fail "Could not find Sparkle generate_appcast. Set SPARKLE_GENERATE_APPCAST or open the app project in Xcode once."
INFO_PLIST="$APP_PATH/Contents/Info.plist"
[[ -f "$INFO_PLIST" ]] || fail "Missing Info.plist in app bundle: $INFO_PLIST"

APP_NAME="$(basename "$APP_PATH")"
ZIP_NAME="${APP_NAME}.zip"
ZIP_PATH="$RELEASE_REPO/$ZIP_NAME"
APPCAST_PATH="$RELEASE_REPO/appcast.xml"
NOTES_BASENAME="${APP_NAME}.md"
NOTES_DEST="$RELEASE_REPO/$NOTES_BASENAME"

SHORT_VERSION="$(plist_read "$INFO_PLIST" "CFBundleShortVersionString")"
BUILD_VERSION="$(plist_read "$INFO_PLIST" "CFBundleVersion")"
FEED_URL="$(plist_read "$INFO_PLIST" "SUFeedURL")"

[[ -n "$SHORT_VERSION" ]] || fail "CFBundleShortVersionString is missing from the app bundle"
[[ -n "$BUILD_VERSION" ]] || fail "CFBundleVersion is missing from the app bundle"

if appcast_contains_build "$APPCAST_PATH" "$SHORT_VERSION" "$BUILD_VERSION"; then
  fail "appcast.xml already contains build $BUILD_VERSION for version $SHORT_VERSION. Bump CFBundleVersion before publishing."
fi

if [[ -z "$DOWNLOAD_URL_PREFIX" ]]; then
  [[ -n "$FEED_URL" ]] || fail "SUFeedURL is missing from the app bundle. Pass --download-url-prefix."
  case "$FEED_URL" in
    */appcast.xml) DOWNLOAD_URL_PREFIX="${FEED_URL%appcast.xml}" ;;
    *) fail "Could not derive download URL prefix from SUFeedURL=$FEED_URL. Pass --download-url-prefix." ;;
  esac
fi

DOWNLOAD_URL_PREFIX="$(ensure_trailing_slash "$DOWNLOAD_URL_PREFIX")"

echo "Using generate_appcast: $GENERATE_APPCAST"
echo "Release repo: $RELEASE_REPO"
echo "Version: $SHORT_VERSION ($BUILD_VERSION)"
echo "Download URL prefix: $DOWNLOAD_URL_PREFIX"

rm -f "$ZIP_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

if [[ -n "$RELEASE_NOTES" ]]; then
  cp "$RELEASE_NOTES" "$NOTES_DEST"
fi

(
  cd "$RELEASE_REPO"
  "$GENERATE_APPCAST" \
    --download-url-prefix "$DOWNLOAD_URL_PREFIX" \
    --release-notes-url-prefix "$DOWNLOAD_URL_PREFIX" \
    .
)

if [[ ! -f "$APPCAST_PATH" ]]; then
  fail "generate_appcast did not create appcast.xml"
fi

git -C "$RELEASE_REPO" status --short

if [[ "$DO_COMMIT" -eq 1 ]]; then
  git -C "$RELEASE_REPO" add "$ZIP_NAME" appcast.xml
  if [[ -n "$RELEASE_NOTES" ]]; then
    git -C "$RELEASE_REPO" add "$NOTES_BASENAME"
  fi

  if [[ -n "$(git -C "$RELEASE_REPO" status --porcelain)" ]]; then
    git -C "$RELEASE_REPO" commit -m "Publish ${APP_NAME%.app} ${SHORT_VERSION} (${BUILD_VERSION})"
  else
    echo "No git changes to commit in $RELEASE_REPO"
  fi
fi

if [[ "$DO_PUSH" -eq 1 ]]; then
  git -C "$RELEASE_REPO" push
fi

echo
echo "Release files are ready:"
echo "  $ZIP_PATH"
echo "  $APPCAST_PATH"
if [[ -f "$NOTES_DEST" ]]; then
  echo "  $NOTES_DEST"
fi
echo
echo "Expected public URLs:"
echo "  ${DOWNLOAD_URL_PREFIX}appcast.xml"
echo "  ${DOWNLOAD_URL_PREFIX}${ZIP_NAME}"
if [[ -f "$NOTES_DEST" ]]; then
  echo "  ${DOWNLOAD_URL_PREFIX}${NOTES_BASENAME}"
fi
