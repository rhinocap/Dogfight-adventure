#!/bin/bash
#
# Deploy Dogfight Adventures to two paired iOS devices and launch a same-Wi-Fi
# multiplayer session. Keep both devices unlocked and awake.
# Usage:
#   bash scripts/deploy_pair.sh <host-device-name|udid> <client-device-name|udid>
#
set -euo pipefail
cd "$(dirname "$0")/.."

HOST="${1:?usage: deploy_pair.sh <host-device> <client-device>}"
CLIENT="${2:?usage: deploy_pair.sh <host-device> <client-device>}"

bash scripts/preflight_devices.sh "$HOST" "$CLIENT"

echo "▶︎ Deploying host on $HOST"
bash scripts/deploy.sh "$HOST" --autostart-host

echo "▶︎ Deploying joiner on $CLIENT"
bash scripts/deploy.sh "$CLIENT" --autostart-join-nearby

echo "✓ Pair launch requested. Both HUDs should show Wi-Fi multiplayer connected."
