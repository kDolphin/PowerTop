#!/bin/bash
set -euo pipefail

APP="${1:-}"
DMG="${2:-}"
if [[ -z "$APP" || ! -d "$APP" || -z "$DMG" ]]; then
    echo "Usage: $0 /path/to/PowerTop.app /path/to/PowerTop.dmg" >&2
    exit 1
fi

STAGING="$(mktemp -d)"
MOUNT_POINT="$(mktemp -d)"
cleanup() {
    hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true
    rm -rf "$STAGING" "$MOUNT_POINT"
}
trap cleanup EXIT

/usr/bin/ditto --noextattr --noqtn "$APP" "$STAGING/PowerTop.app"
ln -s /Applications "$STAGING/Applications"
xattr -cr "$STAGING"

mkdir -p "$(dirname "$DMG")"
rm -f "$DMG"
hdiutil create \
    -volname "PowerTop" \
    -srcfolder "$STAGING" \
    -format UDZO \
    -ov \
    "$DMG"
hdiutil verify "$DMG"

# Mount read-only and verify that both expected entries survived packaging.
hdiutil attach "$DMG" -readonly -nobrowse -mountpoint "$MOUNT_POINT" -quiet
test -d "$MOUNT_POINT/PowerTop.app"
test -L "$MOUNT_POINT/Applications"
[[ "$(readlink "$MOUNT_POINT/Applications")" == "/Applications" ]]
codesign --verify --deep --strict --verbose=4 "$MOUNT_POINT/PowerTop.app"
hdiutil detach "$MOUNT_POINT" -quiet

echo "Created and verified $DMG"
