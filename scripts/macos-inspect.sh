#!/usr/bin/env bash
# Inspect the official Pearl Wallet DMG on a macOS runner:
#   versions, minimum macOS, architectures, code signature / Gatekeeper / notarization,
#   install (copy the app out of the DMG), launch it and take a screenshot, then run the oyster wallet test.
# Usage: macos-inspect.sh <dmg> <expected arch: x86_64|arm64> <output dir> [go-binaries tarball of the same release]
set -uo pipefail
DMG=$1
WANT=$2
OUT=$3
GOBIN_TGZ=${4:-}
HERE=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$OUT"
REPORT=$OUT/report.md
fail=0
note() { echo "$*" | tee -a "$REPORT"; }
plist() { /usr/libexec/PlistBuddy -c "Print :$2" "$1" 2>/dev/null || echo "?"; }

note "### $(basename "$DMG") on $(sw_vers -productName) $(sw_vers -productVersion) $(uname -m)"
MNT=$(mktemp -d)
hdiutil attach -nobrowse -readonly -mountpoint "$MNT" "$DMG" >/dev/null || { note "- DMG does not mount"; exit 1; }
ls -la "$MNT"
APP_SRC=$(find "$MNT" -maxdepth 1 -name '*.app' | head -1)
[ -n "$APP_SRC" ] || { note "- no .app in the DMG"; exit 1; }
mkdir -p "$HOME/Applications"
APP=$HOME/Applications/$(basename "$APP_SRC")
rm -rf "$APP"
ditto "$APP_SRC" "$APP"
hdiutil detach "$MNT" >/dev/null || true

INFO=$APP/Contents/Info.plist
MAIN=$APP/Contents/MacOS/$(plist "$INFO" CFBundleExecutable)
EF="$APP/Contents/Frameworks/Electron Framework.framework/Versions/A/Resources/Info.plist"
OY=$(ls "$APP"/Contents/Resources/bin/oyster-darwin-* 2>/dev/null | head -1)
minos() { vtool -show-build "$1" 2>/dev/null | awk '$1 == "minos" {print $2; exit}'; }

note "- app: $(basename "$APP"), version $(plist "$INFO" CFBundleShortVersionString), bundle id $(plist "$INFO" CFBundleIdentifier)"
note "- Electron $(plist "$EF" CFBundleVersion); LSMinimumSystemVersion $(plist "$INFO" LSMinimumSystemVersion); main binary minos $(minos "$MAIN"), archs $(lipo -archs "$MAIN")"
if [ -z "$OY" ]; then note "- oyster binary not found in Contents/Resources/bin"; exit 1; fi
note "- bundled oyster: $(basename "$OY"), archs $(lipo -archs "$OY"), minos $(minos "$OY"), $(shasum -a 256 "$OY" | cut -c1-16)…"
[ "$(lipo -archs "$MAIN")" = "$WANT" ] || { note "- ✗ main binary is not $WANT"; fail=1; }
[ "$(lipo -archs "$OY")" = "$WANT" ] || { note "- ✗ oyster is not $WANT"; fail=1; }
libs=$(otool -L "$OY" | awk 'NR > 1 {print $1}' | tr '\n' ' ')
note "- oyster links: $libs"

sig=$(codesign -dv --verbose=4 "$APP" 2>&1)
note "- codesign -dv (app):"
grep -E '^(Authority|TeamIdentifier|Signature|CodeDirectory|Runtime|Timestamp|Format)' <<<"$sig" | sed 's/^/    /' | tee -a "$REPORT"
grep -q 'not signed at all' <<<"$sig" && note "    (app is not signed)"
ver=$(codesign --verify --deep --strict --verbose=2 "$APP" 2>&1); note "- codesign --verify --deep --strict: $(tail -1 <<<"$ver")"
gk=$(spctl --assess --type execute -vv "$APP" 2>&1); note "- Gatekeeper (spctl --assess): $(tr '\n' ' ' <<<"$gk")"
st=$(xcrun stapler validate "$APP" 2>&1); note "- notarization ticket (stapler validate): $(tail -1 <<<"$st")"
oysig=$(codesign -dv "$OY" 2>&1); note "- codesign -dv (oyster): $(grep -E '^(Authority|Signature|TeamIdentifier)' <<<"$oysig" | head -2 | tr '\n' ' ')$(grep -q 'not signed' <<<"$oysig" && echo 'not signed')"
note "- quarantine: files fetched by curl carry no quarantine flag, so this run is not stopped by Gatekeeper; a browser download would be (see the spctl line)."

echo "== launch the app"
open "$APP"
sleep 30
procs=$(pgrep -lf "$APP/Contents/MacOS" || true)
if [ -n "$procs" ]; then note "- launched: $(wc -l <<<"$procs" | tr -d ' ') process(es) running after 30 s"; else note "- ✗ app not running 30 s after launch"; fail=1; fi
screencapture -x "$OUT/screenshot-$WANT.png" && note "- screenshot: screenshot-$WANT.png"
osascript -e "quit app \"$(basename "$APP" .app)\"" >/dev/null 2>&1 || true
sleep 5
pkill -f "$APP/Contents" 2>/dev/null || true
pkill -f oyster-darwin 2>/dev/null || true
sleep 2

echo "== what a browser download would see: mark the app as quarantined (as Safari/Chrome do) and launch again"
xattr -w com.apple.quarantine "0083;$(printf '%x' "$(date +%s)");Safari;$(uuidgen)" "$APP"
gkq=$(spctl --assess --type execute -vv "$APP" 2>&1); note "- quarantined: spctl --assess: $(tr '\n' ' ' <<<"$gkq")"
if command -v syspolicy_check >/dev/null 2>&1; then
  spc=$(syspolicy_check distribution "$APP" 2>&1 | head -12); note "- syspolicy_check distribution:"; sed 's/^/    /' <<<"$spc" | tee -a "$REPORT"
fi
# open can block on Gatekeeper's dialog: run it in the background and stop waiting after 20 s.
open "$APP" >/dev/null 2>&1 &
opid=$!
sleep 20
screencapture -x "$OUT/quarantined-launch-$WANT.png"
kill "$opid" 2>/dev/null || true
if pgrep -f "$APP/Contents/MacOS" >/dev/null; then note "- quarantined launch: the app started (Gatekeeper let it run)"; else note "- quarantined launch: the app did NOT start; Gatekeeper's dialog is in quarantined-launch-$WANT.png"; fi
pkill -f "$APP/Contents" 2>/dev/null || true
pkill -f CoreServicesUIAgent 2>/dev/null || true
xattr -dr com.apple.quarantine "$APP"
note "- after xattr -dr com.apple.quarantine (the usual workaround) the app runs, as in the first launch above"
sleep 2

smoke() {  # oyster binary, label
  if bash "$HERE/oyster-smoke.sh" "$1" 2>&1 | tee "$OUT/oyster-smoke-$2.log"; then
    note "- $2 wallet test: $(tail -1 "$OUT/oyster-smoke-$2.log")"
    grep -E '^(address|SPV|restored)' "$OUT/oyster-smoke-$2.log" | sed 's/^/    /' | tee -a "$REPORT"
    return 0
  fi
  note "- ✗ $2 wallet test failed: $(grep -v '^==' "$OUT/oyster-smoke-$2.log" | tail -2 | tr '\n' ' ')"
  return 1
}

echo "== oyster wallet test (the oyster inside the app)"
smoke "$OY" "bundled-oyster-$WANT" || fail=1

if [ -n "$GOBIN_TGZ" ] && [ -f "$GOBIN_TGZ" ]; then
  echo "== the oyster from the release's separate command-line package"
  G=$(mktemp -d); tar xzf "$GOBIN_TGZ" -C "$G"
  GOY=$(find "$G" -type f -name 'oyster*' -perm -u+x | head -1)
  if [ -n "$GOY" ]; then
    note "- $(basename "$GOBIN_TGZ"): oyster archs $(lipo -archs "$GOY"), minos $(minos "$GOY"), $(shasum -a 256 "$GOY" | cut -c1-16)…"
    smoke "$GOY" "cli-package-oyster-$WANT" || true
  else
    note "- no oyster in $(basename "$GOBIN_TGZ")"
  fi
fi
cat "$REPORT" >> "${GITHUB_STEP_SUMMARY:-/dev/null}"
exit $fail
