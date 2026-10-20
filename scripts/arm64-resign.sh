#!/usr/bin/env bash
# Re-sign the official Apple Silicon Pearl Wallet app ad hoc as a whole bundle, and change nothing else.
# The official arm64 app has only the linker's automatic ad-hoc signature on its binaries; the bundle itself has no
# _CodeSignature/CodeResources, so codesign and Gatekeeper report "code has no resources but signature indicates they
# must be present" and macOS calls a downloaded copy "damaged". With a full ad-hoc bundle signature the bundle
# verifies; a downloaded copy then gets the ordinary "could not verify" dialog (still no Developer ID, not notarized).
# Checks: codesign --verify --deep --strict passes; with signatures removed every Mach-O file is byte-identical to the
# official one; every other file is byte-identical; the only new files are inside _CodeSignature directories.
# Usage: arm64-resign.sh <official arm64 dmg> <output dmg>
set -euo pipefail
OFFICIAL=$1
OUT=$2
W=$(mktemp -d)

hdiutil convert "$OFFICIAL" -format UDRW -o "$W/rw.dmg" >/dev/null
mb=$(( $(stat -f%z "$W/rw.dmg") / 1048576 + 200 ))
hdiutil resize -size "${mb}m" "$W/rw.dmg" >/dev/null
M=$W/mnt; mkdir -p "$M"
hdiutil attach -nobrowse -mountpoint "$M" "$W/rw.dmg" >/dev/null
ls -la "$M"
APP=$(find "$M" -maxdepth 1 -name '*.app' | head -1)
ditto "$APP" "$W/orig.app"

echo "== official bundle: $(codesign --verify --deep --strict "$APP" 2>&1 | tail -1)"
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
codesign -dv "$APP" 2>&1 | grep -E '^(Format|CodeDirectory|Signature|Sealed Resources)' || true

echo "== compare with the official app"
bad=0; macho=0; same=0; newfiles=0
strip_sig() { cp "$1" "$2"; chmod u+w "$2"; codesign --remove-signature "$2" 2>/dev/null || true; }
while IFS= read -r -d '' f; do
  rel=${f#"$APP"/}
  o="$W/orig.app/$rel"
  if [ ! -e "$o" ]; then
    case "$rel" in */_CodeSignature/*|_CodeSignature/*) newfiles=$((newfiles + 1)) ;; *) echo "new file outside _CodeSignature: $rel"; bad=1 ;; esac
    continue
  fi
  if cmp -s "$f" "$o"; then same=$((same + 1)); continue; fi
  if file -b "$o" | grep -q 'Mach-O'; then
    strip_sig "$f" "$W/a"; strip_sig "$o" "$W/b"
    if cmp -s "$W/a" "$W/b"; then macho=$((macho + 1)); else echo "Mach-O differs beyond its signature: $rel"; bad=1; fi
  else
    case "$rel" in */_CodeSignature/*) newfiles=$((newfiles + 1)) ;; *) echo "file changed: $rel"; bad=1 ;; esac
  fi
done < <(find "$APP" -type f -print0)
missing=$(cd "$W/orig.app" && find . -type f | while read -r r; do [ -e "$APP/${r#./}" ] || echo "$r"; done)
[ -z "$missing" ] || { echo "files missing after re-signing: $missing"; bad=1; }
echo "identical files: $same; Mach-O files that differ only in their signature: $macho; new/changed _CodeSignature files: $newfiles"
[ "$bad" = 0 ] || { echo "re-signing changed more than signatures" >&2; exit 1; }

hdiutil detach "$M" >/dev/null
rm -f "$OUT"
hdiutil convert "$W/rw.dmg" -format UDZO -o "$OUT" >/dev/null
hdiutil verify "$OUT" >/dev/null
echo "wrote $OUT: sha256 $(shasum -a 256 "$OUT" | cut -d' ' -f1)"
rm -rf "$W"
