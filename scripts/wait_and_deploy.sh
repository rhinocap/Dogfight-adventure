#!/bin/bash
#
# Waits for the declan iPad/iPhone to be trusted on this Mac, then auto-builds
# (CPU-capped), installs, and launches the game on each — identified by UDID via
# elimination (any iPhone/iPad that is NOT Andrew's 17 Pro or the Apple Watch).
#
set -uo pipefail
cd "$(dirname "$0")/.."

BUNDLE="com.cunliffe.dogfightadventures"
# Known non-target devices to ignore.
EXCLUDE="00008150-000D05903688401C 00008310-00034AD01E40E01E"
DEADLINE=$(( $(date +%s) + 2400 ))   # 40 min
DEPLOYED_FILE=$(mktemp)

log() { echo "[$(date +%H:%M:%S)] $*"; }

deploy_one() {  # $1=udid  $2=name
  local udid="$1" name="$2"
  log "▶︎ Building (CPU-capped) + deploying to '$name' [$udid]…"
  if CONFIG=Release bash scripts/build.sh "id=$udid" -allowProvisioningUpdates >"/tmp/dogfight/build_${udid}.log" 2>&1; then
    local app
    app=$(find build/DerivedData/Build/Products/Release-iphoneos -name "*.app" -maxdepth 2 | head -1)
    log "  installing $app"
    if xcrun devicectl device install app --device "$udid" "$app" >>"/tmp/dogfight/build_${udid}.log" 2>&1; then
      xcrun devicectl device process launch --device "$udid" "$BUNDLE" >>"/tmp/dogfight/build_${udid}.log" 2>&1 \
        && log "✓✓ Launched on '$name'" || log "  installed but launch returned nonzero (check log)"
      echo "$udid" >> "$DEPLOYED_FILE"
      return 0
    else
      log "  ✗ install failed (see /tmp/dogfight/build_${udid}.log)"
    fi
  else
    log "  ✗ build/signing failed (see /tmp/dogfight/build_${udid}.log)"
    tail -3 "/tmp/dogfight/build_${udid}.log" | sed 's/^/     /'
  fi
  return 1
}

log "Watching for declan iPad/iPhone to be paired (USB + Trust)…"

ROWS_FILE=$(mktemp)
while :; do
  xcrun devicectl list devices --json-output /tmp/dogfight/devs.json >/dev/null 2>&1 || true
  # Emit "udid|name|type|pairing" lines for candidate devices (bash 3.2 — no mapfile).
  python3 - "$EXCLUDE" >"$ROWS_FILE" <<'PY'
import json,sys
exclude=set(sys.argv[1].split())
try: d=json.load(open('/tmp/dogfight/devs.json'))
except Exception: sys.exit(0)
for dev in d.get('result',{}).get('devices',[]):
    hp=dev.get('hardwareProperties',{}); cp=dev.get('connectionProperties',{}); dp=dev.get('deviceProperties',{})
    t=hp.get('deviceType'); u=hp.get('udid','')
    if t in ('iPhone','iPad') and u and u not in exclude:
        print(f"{u}|{dp.get('name','?')}|{t}|{cp.get('pairingState','?')}")
PY

  while IFS='|' read -r udid name typ pairing; do
    [ -z "$udid" ] && continue
    grep -q "^$udid$" "$DEPLOYED_FILE" 2>/dev/null && continue
    if [ "$pairing" = "paired" ]; then
      deploy_one "$udid" "$name"
    else
      log "… '$name' ($typ) present but $pairing — tap 'Trust This Computer' on it. (initiating pair)"
      xcrun devicectl manage pair --device "$udid" --timeout 15 >/dev/null 2>&1 || true
    fi
  done < "$ROWS_FILE"

  # Stop once we've deployed to at least one iPad AND one iPhone (best-effort), or timeout.
  ipad_done=0; iphone_done=0
  while IFS='|' read -r udid name typ pairing; do
    [ -z "$udid" ] && continue
    if grep -q "^$udid$" "$DEPLOYED_FILE" 2>/dev/null; then
      [ "$typ" = "iPad" ] && ipad_done=1
      [ "$typ" = "iPhone" ] && iphone_done=1
    fi
  done < "$ROWS_FILE"
  if [ "$ipad_done" = 1 ] && [ "$iphone_done" = 1 ]; then
    log "✓ Deployed to both an iPad and an iPhone. Done."
    exit 0
  fi

  [ "$(date +%s)" -ge "$DEADLINE" ] && { log "Timed out. Deployed UDIDs: $(tr '\n' ' ' <"$DEPLOYED_FILE")"; exit 3; }
  sleep 5
done
