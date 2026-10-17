#!/bin/bash
# Builds Tabbit (Release) and installs it into /Applications.
#
#   scripts/install.sh
#
# Needs Xcode (the full app, not just the Command Line Tools). Node is not needed: the web
# bundle in Tabbit/Resources/web is committed. Environment overrides:
#   TABBIT_INSTALL_DIR  where to install (default: /Applications)
#   TABBIT_BUILD_DIR    xcodebuild derived data (default: ~/Library/Caches/tabbit-build)
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
INSTALL_DIR="${TABBIT_INSTALL_DIR:-/Applications}"
# Build outside the repo: in an iCloud-synced folder (e.g. ~/Documents) new files get
# extended attributes, and codesign refuses to sign the app.
BUILD_DIR="${TABBIT_BUILD_DIR:-$HOME/Library/Caches/tabbit-build}"
APP="$BUILD_DIR/Build/Products/Release/Tabbit.app"
DEST="$INSTALL_DIR/Tabbit.app"
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

# xcodebuild fails if xcode-select points at the Command Line Tools; use Xcode.app directly.
if ! xcodebuild -version >/dev/null 2>&1; then
  if [[ -d /Applications/Xcode.app ]]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
  else
    echo "error: Xcode is required. Install it from the App Store, open it once, then re-run." >&2
    exit 1
  fi
fi

if pgrep -xq Tabbit; then
  echo "error: Tabbit is running. Quit it (⌘Q), then run this script again." >&2
  exit 1
fi

echo "==> Building Tabbit (Release, universal)"
xcodebuild -project "$REPO/Tabbit.xcodeproj" -scheme Tabbit -configuration Release \
  -destination 'generic/platform=macOS' -derivedDataPath "$BUILD_DIR" -quiet build
codesign --verify --strict "$APP"

mkdir -p "$INSTALL_DIR" 2>/dev/null || true
# Only ask for an admin password if the install folder isn't writable.
as_installer() {
  if [[ -w "$INSTALL_DIR" ]]; then "$@"; else sudo "$@"; fi
}

echo "==> Installing to $DEST"
as_installer rm -rf "$DEST"
as_installer ditto "$APP" "$DEST"

# Make Finder's "Open With" pick up the document types right away, and list only the
# installed copy (building registers the one in the build folder too).
"$LSREGISTER" -f "$DEST"
"$LSREGISTER" -u "$APP" 2>/dev/null || true

echo "==> Done. Open Markdown or HTML files with Tabbit, or run: open -a Tabbit"
