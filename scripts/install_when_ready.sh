#!/bin/bash
# Waits for Developer Mode on a specific device, then installs + launches the
# already-built signed app (no rebuild — the wildcard profile covers it).
# Usage: install_when_ready.sh <udid> <label>
set -uo pipefail
cd "$(dirname "$0")/.."
UDID="${1:?udid}"; LABEL="${2:-$1}"; BUNDLE="com.cunliffe.dogfightadventures"
APP=$(find build/DerivedData/Build/Products/Release-iphoneos -name "*.app" -maxdepth 2 | head -1)
DEADLINE=$(( $(date +%s) + 2400 ))
log(){ echo "[$(date +%H:%M:%S)] $*"; }
log "Waiting for Developer Mode on $LABEL [$UDID]… (app ready: $APP)"
while :; do
  if xcrun devicectl device info details --device "$UDID" 2>/dev/null | grep -qi "developerModeStatus: enabled"; then
    log "Developer Mode ON for $LABEL — installing…"
    if xcrun devicectl device install app --device "$UDID" "$APP" >/tmp/dogfight/install_${UDID}.log 2>&1 \
       && xcrun devicectl device process launch --device "$UDID" "$BUNDLE" >>/tmp/dogfight/install_${UDID}.log 2>&1; then
      log "✓✓ LAUNCHED on $LABEL"; exit 0
    fi
    log "✗ install/launch failed (see /tmp/dogfight/install_${UDID}.log)"; tail -4 /tmp/dogfight/install_${UDID}.log | sed 's/^/   /'; exit 1
  fi
  [ "$(date +%s)" -ge "$DEADLINE" ] && { log "Timed out waiting for Developer Mode on $LABEL"; exit 3; }
  sleep 8
done
