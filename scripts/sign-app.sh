#!/bin/bash
set -euo pipefail

APP="${1:-}"
if [[ -z "$APP" || ! -d "$APP" ]]; then
    echo "Usage: $0 /path/to/PowerTop.app" >&2
    exit 1
fi

# Extended attributes must be removed before signing because changing bundle
# contents or metadata afterwards can invalidate the resource seal.
xattr -cr "$APP"

# Sign every Mach-O explicitly. This includes executables and dynamic libraries
# even when an executable bit is missing.
while IFS= read -r -d '' candidate; do
    if file -b "$candidate" | grep -q 'Mach-O'; then
        codesign --force --sign - --timestamp=none "$candidate"
    fi
done < <(find "$APP/Contents" -type f -print0)

# Sign nested code bundles from the inside out. Sorting by path length makes
# deeper bundles precede their containers and also works with macOS Bash 3.2.
while IFS= read -r bundle; do
    [[ -n "$bundle" ]] || continue
    codesign --force --sign - --timestamp=none "$bundle"
done < <(find "$APP/Contents" -type d \( \
    -name '*.framework' -o \
    -name '*.xpc' -o \
    -name '*.appex' -o \
    -name '*.plugin' -o \
    -name '*.bundle' -o \
    -name '*.app' \
\) -print | awk '{ print length($0) "\t" $0 }' | sort -rn | cut -f2-)

codesign --force --sign - --timestamp=none "$APP"
xattr -cr "$APP"
