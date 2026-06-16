#!/bin/bash
#
# Build, install, and launch a two-simulator local multiplayer smoke test.
# Usage:
#   bash scripts/verify_sim_multiplayer.sh <host-sim-udid> <client-sim-udid>
#
set -euo pipefail
cd "$(dirname "$0")/.."

HOST="${1:?usage: verify_sim_multiplayer.sh <host-sim-udid> <client-sim-udid>}"
CLIENT="${2:?usage: verify_sim_multiplayer.sh <host-sim-udid> <client-sim-udid>}"
BUNDLE="com.cunliffe.dogfightadventures"
OUT="${OUT:-/tmp/dogfight-adventures}"

mkdir -p "$OUT"

echo "▶︎ Building simulator app"
bash scripts/build.sh >/tmp/dogfight-sim-multiplayer-build.log
tail -5 /tmp/dogfight-sim-multiplayer-build.log

APP="build/DerivedData/Build/Products/Debug-iphonesimulator/DogfightAdventures.app"

echo "▶︎ Booting simulators"
xcrun simctl boot "$HOST" >/dev/null 2>&1 || true
xcrun simctl boot "$CLIENT" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$HOST" -b
xcrun simctl bootstatus "$CLIENT" -b

echo "▶︎ Installing app"
xcrun simctl install "$HOST" "$APP"
xcrun simctl install "$CLIENT" "$APP"

xcrun simctl terminate "$HOST" "$BUNDLE" >/dev/null 2>&1 || true
xcrun simctl terminate "$CLIENT" "$BUNDLE" >/dev/null 2>&1 || true

echo "▶︎ Launching host"
xcrun simctl launch "$HOST" "$BUNDLE" --autostart-host
sleep 2

echo "▶︎ Launching joiner"
xcrun simctl launch "$CLIENT" "$BUNDLE" --autostart-join-nearby
sleep 6

HOST_SHOT="$OUT/sim-host-wifi.png"
CLIENT_SHOT="$OUT/sim-client-wifi.png"
xcrun simctl io "$HOST" screenshot "$HOST_SHOT"
xcrun simctl io "$CLIENT" screenshot "$CLIENT_SHOT"

echo "✓ Screenshots:"
echo "  $HOST_SHOT"
echo "  $CLIENT_SHOT"
