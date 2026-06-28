#!/bin/bash
set -euo pipefail

APP="${1:-}"
EXPECTED_VERSION="${2:-}"
if [[ -z "$APP" || ! -d "$APP" ]]; then
    echo "Usage: $0 /path/to/PowerTop.app [expected-version]" >&2
    exit 1
fi

PLIST="$APP/Contents/Info.plist"
EXECUTABLE="$APP/Contents/MacOS/PowerTop"
test -f "$PLIST"
test -x "$EXECUTABLE"
plutil -lint "$PLIST" >/dev/null

[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$PLIST")" == "com.kdolphin.PowerTop" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$PLIST")" == "PowerTop" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundlePackageType' "$PLIST")" == "APPL" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$PLIST")" == "14.0" ]]
BUNDLE_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$PLIST")"
[[ "$BUNDLE_VERSION" =~ ^[1-9][0-9]*$ ]]
if [[ -n "$EXPECTED_VERSION" ]]; then
    [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PLIST")" == "$EXPECTED_VERSION" ]]
fi

file "$EXECUTABLE" | grep -q 'Mach-O 64-bit executable arm64'

while IFS= read -r -d '' executable_file; do
    if ! file -b "$executable_file" | grep -q 'Mach-O'; then
        echo "Unsigned non-Mach-O executable in bundle: $executable_file" >&2
        exit 1
    fi
done < <(find "$APP/Contents" -type f -perm -111 -print0)

if find "$APP" \( \
    -name '.DS_Store' -o \
    -name '._*' -o \
    -name '*.swp' -o \
    -name '*.tmp' -o \
    -name '*~' -o \
    -name '*.xcassets' \
\) -print -quit | grep -q .; then
    echo "Bundle contains temporary or source-only files:" >&2
    find "$APP" \( \
        -name '.DS_Store' -o -name '._*' -o -name '*.swp' -o \
        -name '*.tmp' -o -name '*~' -o -name '*.xcassets' \
    \) -print >&2
    exit 1
fi

# Provenance can be re-applied by macOS when generated files are accessed. It
# is harmless; reject attributes that can alter Finder behavior or quarantine
# the release instead.
if xattr -lr "$APP" 2>/dev/null | grep -Eq \
    'com[.]apple[.](quarantine|ResourceFork|FinderInfo)|com[.]apple[.]metadata:'; then
    echo "Bundle contains prohibited extended attributes:" >&2
    xattr -lr "$APP" >&2
    exit 1
fi

while IFS= read -r -d '' candidate; do
    if file -b "$candidate" | grep -q 'Mach-O'; then
        codesign --verify --strict --verbose=2 "$candidate"
    fi
done < <(find "$APP/Contents" -type f -print0)

while IFS= read -r -d '' bundle; do
    codesign --verify --strict --verbose=2 "$bundle"
done < <(find "$APP/Contents" -type d \( \
    -name '*.framework' -o \
    -name '*.xpc' -o \
    -name '*.appex' -o \
    -name '*.plugin' -o \
    -name '*.bundle' -o \
    -name '*.app' \
\) -print0)

# Required release acceptance check.
codesign --verify --deep --strict --verbose=4 "$APP"
echo "Verified $APP"
