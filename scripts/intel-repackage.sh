#!/usr/bin/env bash
# Put a native x86_64 oyster into the official Intel Pearl Wallet DMG and change nothing else.
# The official Intel DMG ships Contents/Resources/bin/oyster-darwin-x64 built for arm64 (its build job ran on an
# arm64 runner with only GOOS set), so the wallet backend cannot start on an Intel Mac ("Bad CPU type").
# Checks: the replaced file was arm64 before and is x86_64 after; every other file in the app is byte-identical.
# Usage: intel-repackage.sh <official Intel dmg> <x86_64 oyster> <output dmg>
set -euo pipefail
OFFICIAL=$1
NEWOY=$2
OUT=$3
REL=Contents/Resources/bin/oyster-darwin-x64
W=$(mktemp -d)

[ "$(lipo -archs "$NEWOY")" = x86_64 ] || { echo "new oyster is not x86_64" >&2; exit 1; }
hdiutil convert "$OFFICIAL" -format UDRW -o "$W/rw.dmg" >/dev/null
mb=$(( $(stat -f%z "$W/rw.dmg") / 1048576 + 200 ))
hdiutil resize -size "${mb}m" "$W/rw.dmg" >/dev/null
M=$W/mnt; mkdir -p "$M"
hdiutil attach -nobrowse -mountpoint "$M" "$W/rw.dmg" >/dev/null
ls -la "$M"
APP=$(find "$M" -maxdepth 1 -name '*.app' | head -1)
T=$APP/$REL
test -f "$T"
echo "official $REL: archs $(lipo -archs "$T"), sha256 $(shasum -a 256 "$T" | cut -d' ' -f1)"

manifest() { (cd "$APP" && find . -type f ! -path "./$REL" -exec shasum -a 256 {} + | sort -k2); }
manifest > "$W/before.txt"
cp -f "$NEWOY" "$T"
chmod 755 "$T"
manifest > "$W/after.txt"
if ! diff -q "$W/before.txt" "$W/after.txt" >/dev/null; then echo "files other than $REL changed" >&2; diff "$W/before.txt" "$W/after.txt" | head >&2; exit 1; fi
echo "other files unchanged: $(wc -l < "$W/after.txt" | tr -d ' ') files compared"
echo "new $REL: archs $(lipo -archs "$T"), sha256 $(shasum -a 256 "$T" | cut -d' ' -f1)"
[ "$(lipo -archs "$T")" = x86_64 ]
cmp "$NEWOY" "$T"

hdiutil detach "$M" >/dev/null
rm -f "$OUT"
hdiutil convert "$W/rw.dmg" -format UDZO -o "$OUT" >/dev/null
hdiutil verify "$OUT" >/dev/null
echo "wrote $OUT: sha256 $(shasum -a 256 "$OUT" | cut -d' ' -f1)"
rm -rf "$W"
