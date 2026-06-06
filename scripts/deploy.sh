#!/bin/bash
#
# Install + launch Dogfight Adventures on a PAIRED physical device.
# Usage: bash scripts/deploy.sh <device-name>   e.g. declan-ipad
#
# Requires the device to be paired/trusted with this Mac (USB once, "Trust",
# then optionally "Connect via network"). Tailscale IP reachability alone is
# NOT sufficient — see README.
#
set -euo pipefail
cd "$(dirname "$0")/.."

DEVICE="${1:?usage: deploy.sh <device-name>}"
BUNDLE_ID="com.cunliffe.dogfightadventures"

echo "▶︎ Checking that '$DEVICE' is paired with this Mac…"
if ! xcrun devicectl list devices 2>/dev/null | grep -qi "$DEVICE"; then
  echo "✗ '$DEVICE' is not paired with this Mac."
  echo "  Paired devices:"
  xcrun devicectl list devices 2>/dev/null | sed 's/^/    /'
  echo
  echo "  Pair it once over USB (tap 'Trust This Computer'), then retry."
  echo "  Tailscale reachability ($(tailscale ip -4 "$DEVICE" 2>/dev/null || echo '?')) is not enough for app install."
  exit 2
fi

echo "▶︎ Building signed Release for device…"
CONFIG=Release bash scripts/build.sh "platform=iOS,name=$DEVICE"

APP=$(find build/DerivedData/Build/Products/Release-iphoneos -name "*.app" -maxdepth 2 | head -1)
echo "▶︎ Installing $APP → $DEVICE"
xcrun devicectl device install app --device "$DEVICE" "$APP"

echo "▶︎ Launching…"
xcrun devicectl device process launch --device "$DEVICE" "$BUNDLE_ID"
echo "✓ Launched on $DEVICE"
