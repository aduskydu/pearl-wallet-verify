#!/usr/bin/env bash
# What a user meets when opening a downloaded copy, and which workaround gets the app to start.
# Each case uses a fresh copy of the app at its own path, marked with the quarantine flag a browser sets:
#   A  remove the flag BEFORE the first launch (xattr -dr com.apple.quarantine), then launch;
#   B  launch with the flag (Gatekeeper blocks it), dismiss the dialog, then
#      B1 remove only the quarantine flag and launch again; if still blocked,
#      B2 clear all extended attributes (xattr -cr) and launch again.
# Usage: gatekeeper-test.sh <dmg> <label> <output dir>
set -uo pipefail
DMG=$1
LABEL=$2
OUT=$3
mkdir -p "$OUT"
REPORT=$OUT/gatekeeper-$LABEL.md
note() { echo "$*" | tee -a "$REPORT"; }

MNT=$(mktemp -d)
hdiutil attach -nobrowse -readonly -mountpoint "$MNT" "$DMG" >/dev/null || { note "- $LABEL: DMG does not mount"; exit 1; }
SRC=$(find "$MNT" -maxdepth 1 -name '*.app' | head -1)
NAME=$(basename "$SRC" .app)
fresh() { local d="$HOME/gk/$LABEL-$1"; rm -rf "$d"; mkdir -p "$d"; ditto "$SRC" "$d/$NAME.app"; echo "$d/$NAME.app"; }
quarantine() { xattr -w com.apple.quarantine "0083;$(printf '%x' "$(date +%s)");Safari;$(uuidgen)" "$1"; }
dismiss() { killall CoreServicesUIAgent 2>/dev/null || true; killall UserNotificationCenter 2>/dev/null || true; sleep 5; }
launch() {  # app, shot name -> prints started|blocked
  local app=$1 shot=$2 opid r
  open "$app" >/dev/null 2>&1 &
  opid=$!
  sleep 20
  screencapture -x "$OUT/$shot.png"
  if pgrep -f "$app/Contents/MacOS" >/dev/null; then r=started; else r=blocked; fi
  kill "$opid" 2>/dev/null || true
  osascript -e "quit app \"$NAME\"" >/dev/null 2>&1 || true
  sleep 3
  pkill -f "$app/Contents" 2>/dev/null || true
  pkill -f oyster-darwin 2>/dev/null || true
  dismiss
  echo "$r"
}

note "### Gatekeeper: $LABEL ($(basename "$DMG")), macOS $(sw_vers -productVersion) $(uname -m)"
dismiss

A=$(fresh A)
quarantine "$A"
xattr -dr com.apple.quarantine "$A"
note "- A, flag removed before the first launch: $(launch "$A" "gk-$LABEL-A")"

B=$(fresh B)
quarantine "$B"
note "- B, launched with the flag: $(launch "$B" "gk-$LABEL-B0") (dialog in gk-$LABEL-B0.png)"
note "  extended attributes after the blocked launch: app [$(xattr "$B" | tr '\n' ' ')], main binary [$(xattr "$B/Contents/MacOS/$NAME" | tr '\n' ' ')]"
xattr -dr com.apple.quarantine "$B"
r1=$(launch "$B" "gk-$LABEL-B1")
note "- B1, then xattr -dr com.apple.quarantine: $r1"
if [ "$r1" != started ]; then
  xattr -cr "$B"
  note "- B2, then xattr -cr: $(launch "$B" "gk-$LABEL-B2")"
fi
hdiutil detach "$MNT" >/dev/null 2>&1 || true
cat "$REPORT" >> "${GITHUB_STEP_SUMMARY:-/dev/null}"
