#!/usr/bin/env bash
# Wallet test of the oyster binary that ships inside the official Pearl Wallet app.
# Same flow as the desktop app (apps/apps/pearl-desktop-wallet/src/main/services/wallet-process.ts):
#   1. oyster --createfromfile=<json with PrivatePassphrase> creates a mainnet wallet and prints a 12-word mnemonic;
#   2. oyster --usespv ... runs the wallet (SPV, mainnet) with the legacy JSON-RPC server on 127.0.0.1;
#   3. getnewaddress must return a prl1... address;
#   4. a second wallet created from that mnemonic must return the same first address (the backup restores);
#   5. reports how far SPV got with the live network in a short window (informational).
# Nothing here touches real funds: fresh throwaway wallets in a temp directory, deleted at the end.
# Usage: oyster-smoke.sh <path to oyster binary> [rpc port]
set -euo pipefail
OY=$1
PORT=${2:-44217}
W=$(mktemp -d)
U=smoke
P=$(od -An -N12 -tx1 /dev/urandom | tr -d ' \n')
PIDFILE=$W/pid
winpath() { if command -v cygpath >/dev/null 2>&1; then cygpath -w "$1"; else printf '%s' "$1"; fi; }

cleanup() {
  if [ -f "$PIDFILE" ]; then kill "$(cat "$PIDFILE")" 2>/dev/null || true; fi
  rm -rf "$W"
}
trap cleanup EXIT

rpc() {  # method [json params]
  curl -s --max-time 15 -u "$U:$P" -H 'Content-Type: application/json' \
    -d "{\"jsonrpc\":\"1.0\",\"id\":1,\"method\":\"$1\",\"params\":${2:-[]}}" "http://127.0.0.1:$PORT/" || true
}

set_args() {  # appdata dir -> ARGS (no mapfile: macOS ships bash 3.2)
  ARGS=(--usespv "--appdata=$(winpath "$1")" "--username=$U" "--password=$P" "--rpclisten=127.0.0.1:$PORT" --noservertls)
}

create() {  # appdata dir, json -> stdout of oyster
  local d=$1 json=$2
  mkdir -p "$d"
  printf '%s' "$json" > "$d/setup.json"
  set_args "$d"
  "$OY" "${ARGS[@]}" "--createfromfile=$(winpath "$d/setup.json")" 2>&1
  rm -f "$d/setup.json"
}

start() {  # appdata dir
  local d=$1 i
  set_args "$d"
  "$OY" "${ARGS[@]}" > "$d/run.log" 2>&1 &
  echo $! > "$PIDFILE"
  for i in $(seq 1 60); do
    if rpc getinfo | jq -e '.result != null' >/dev/null 2>&1; then return 0; fi
    sleep 2
  done
  echo "oyster RPC did not come up; last log lines:" >&2
  tail -40 "$d/run.log" >&2
  return 1
}

stop() {
  rpc stop >/dev/null
  local pid; pid=$(cat "$PIDFILE")
  for _ in $(seq 1 30); do kill -0 "$pid" 2>/dev/null || break; sleep 1; done
  kill "$pid" 2>/dev/null || true
  rm -f "$PIDFILE"
}

echo "== 0. version"
"$OY" --version

echo "== 1. new wallet (createfromfile, mainnet)"
out=$(create "$W/a" "{\"PrivatePassphrase\":\"$P\"}")
mnemonic=$(grep -E '^[a-z]+( [a-z]+){11}$' <<<"$out" | head -1 || true)
words=$(wc -w <<<"$mnemonic" | tr -d ' ')
[ "$words" = 12 ] || { echo "no 12-word mnemonic printed; output was:" >&2; echo "$out" >&2; exit 1; }
echo "12-word mnemonic printed (not shown)"

echo "== 2. run the wallet (SPV) and get a new address"
start "$W/a"
info=$(rpc getinfo)
jq -c '.result | {version, protocolversion, blocks, connections, testnet}' <<<"$info" || echo "$info"
addr1=$(rpc getnewaddress | jq -r '.result // empty')
echo "address: $addr1"
[[ "$addr1" =~ ^prl1[02-9ac-hj-np-z]{20,}$ ]] || { echo "not a prl1 address: '$addr1'" >&2; exit 1; }
valid=$(rpc validateaddress "[\"$addr1\"]")
jq -c '.result | {isvalid, ismine, iswitness, witness_version}' <<<"$valid" || true
jq -e '.result.isvalid == true and .result.ismine == true' >/dev/null <<<"$valid" || { echo "validateaddress: $valid" >&2; exit 1; }

echo "== 3. SPV progress with the live network (90 s, informational)"
best=0
for _ in $(seq 1 18); do
  b=$(rpc getinfo | jq -r '.result.blocks // 0' 2>/dev/null || echo 0)
  c=$(rpc getinfo | jq -r '.result.connections // 0' 2>/dev/null || echo 0)
  [ "$b" -gt "$best" ] 2>/dev/null && best=$b
  sleep 5
done
echo "SPV: best block height seen ${best}, peers ${c:-0}"
stop

echo "== 4. restore from the mnemonic: same first address"
create "$W/b" "{\"PrivatePassphrase\":\"$P\",\"Seed\":\"$mnemonic\",\"Bday\":\"1724644369\"}" >/dev/null
start "$W/b"
addr2=$(rpc getnewaddress | jq -r '.result // empty')
echo "restored wallet first address: $addr2"
stop
[ "$addr1" = "$addr2" ] || { echo "restored wallet gives a different first address" >&2; exit 1; }

echo "== 5. a second brand-new wallet gets a different address"
create "$W/c" "{\"PrivatePassphrase\":\"$P\"}" >/dev/null
start "$W/c"
addr3=$(rpc getnewaddress | jq -r '.result // empty')
stop
echo "second new wallet first address: $addr3"
[ -n "$addr3" ] && [ "$addr3" != "$addr1" ] || { echo "second new wallet did not get a different address" >&2; exit 1; }

echo "oyster smoke test OK: mnemonic printed, prl1 address, mnemonic restores the same address, new wallets get new keys"
