#!/bin/bash
#
# Hands-off deploy: does NOTHING until Developer Mode is enabled on a declan
# device (iPad/iPhone that isn't Andrew's 17 Pro or Watch). Only then does it
# build (CPU-capped), install, and launch — so no wasteful spinning while we
# wait for the on-device toggle. Exits once both an iPad and iPhone are done.
#
set -uo pipefail
cd "$(dirname "$0")/.."

BUNDLE="com.cunliffe.dogfightadventures"
EXCLUDE="00008150-000D05903688401C 00008310-00034AD01E40E01E"
DEADLINE=$(( $(date +%s) + 3000 ))   # 50 min
DEPLOYED=$(mktemp)
ROWS=$(mktemp)

log() { echo "[$(date +%H:%M:%S)] $*"; }

deploy_one() {  # udid name
  local udid="$1" name="$2" blog="/tmp/dogfight/build_${1}.log"
  log "▶︎ Developer Mode ON for '$name' — building + deploying [$udid]…"
  if CONFIG=Release bash scripts/build.sh "id=$udid" -allowProvisioningUpdates >"$blog" 2>&1; then
    local app; app=$(find build/DerivedData/Build/Products/Release-iphoneos -name "*.app" -maxdepth 2 | head -1)
    if xcrun devicectl device install app --device "$udid" "$app" >>"$blog" 2>&1; then
      if xcrun devicectl device process launch --device "$udid" "$BUNDLE" >>"$blog" 2>&1; then
        log "✓✓ LAUNCHED on '$name'"; echo "$udid" >>"$DEPLOYED"; return 0
      fi
      log "  installed but launch failed (see $blog)"; echo "$udid" >>"$DEPLOYED"; return 0
    fi
    log "  ✗ install failed (see $blog)"; tail -4 "$blog" | sed 's/^/     /'
  else
    log "  ✗ build/signing failed (see $blog)"; grep -iE "error:|provisioning|signing|developer mode" "$blog" | head -4 | sed 's/^/     /'
  fi
  return 1
}

log "Armed. Waiting for Developer Mode to be enabled on the declan iPad/iPhone…"
while :; do
  xcrun devicectl list devices --json-output /tmp/dogfight/devs.json >/dev/null 2>&1 || true
  python3 - "$EXCLUDE" >"$ROWS" <<'PY'
import json,sys
exclude=set(sys.argv[1].split())
try: d=json.load(open('/tmp/dogfight/devs.json'))
except Exception: sys.exit(0)
for dev in d.get('result',{}).get('devices',[]):
    hp=dev.get('hardwareProperties',{}); dp=dev.get('deviceProperties',{})
    t=hp.get('deviceType'); u=hp.get('udid','')
    if t in ('iPhone','iPad') and u and u not in exclude:
        print(f"{u}|{dp.get('name','?')}|{t}")
PY

  while IFS='|' read -r udid name typ; do
    [ -z "$udid" ] && continue
    grep -q "^$udid$" "$DEPLOYED" 2>/dev/null && continue
    # Cheap readiness probe — no build unless Developer Mode is actually on.
    info=$(xcrun devicectl device info details --device "$udid" 2>/dev/null | grep -iE "developerModeStatus|ddiServicesAvailable")
    if echo "$info" | grep -qi "developerModeStatus: enabled"; then
      deploy_one "$udid" "$name"
    fi
  done < "$ROWS"

  ipad=0; iphone=0
  while IFS='|' read -r udid name typ; do
    [ -z "$udid" ] && continue
    if grep -q "^$udid$" "$DEPLOYED" 2>/dev/null; then
      [ "$typ" = "iPad" ] && ipad=1; [ "$typ" = "iPhone" ] && iphone=1
    fi
  done < "$ROWS"
  { [ "$ipad" = 1 ] && [ "$iphone" = 1 ]; } && { log "✓ Both iPad and iPhone deployed. Done."; exit 0; }

  [ "$(date +%s)" -ge "$DEADLINE" ] && { log "Timed out. Deployed: $(tr '\n' ' ' <"$DEPLOYED")"; exit 3; }
  sleep 8
done
