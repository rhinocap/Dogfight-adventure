#!/bin/bash
#
# Validate that paired physical iOS devices are ready for xcodebuild deploy.
# Usage: bash scripts/preflight_devices.sh <device-name|udid> [...]
#
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ "$#" -lt 1 ]]; then
  echo "usage: preflight_devices.sh <device-name|udid> [...]" >&2
  exit 2
fi

STATUS=0

for DEVICE in "$@"; do
  SAFE="$(echo "$DEVICE" | tr -c 'A-Za-z0-9_.-' '_')"
  JSON="/tmp/dogfight-device-${SAFE}.json"
  LOG="/tmp/dogfight-device-${SAFE}.log"
  DDI_JSON="/tmp/dogfight-device-${SAFE}-ddi.json"
  DDI_LOG="/tmp/dogfight-device-${SAFE}-ddi.log"

  echo "▶︎ Preflight: $DEVICE"
  if ! xcrun devicectl device info details --device "$DEVICE" --json-output "$JSON" >"$LOG" 2>&1; then
    echo "FAIL $DEVICE: devicectl could not read device details"
    sed -n '1,80p' "$LOG"
    STATUS=1
    continue
  fi

  if ! xcrun devicectl device info ddiServices --device "$DEVICE" --json-output "$DDI_JSON" >"$DDI_LOG" 2>&1; then
    echo "FAIL $DEVICE: developer disk image services could not be mounted"
    python3 - "$JSON" "$DDI_JSON" "$DDI_LOG" <<'PY'
import json
import sys

details_path, json_path, log_path = sys.argv[1:]
try:
    details = json.load(open(details_path)).get("result", {})
except Exception:
    details = {}
try:
    data = json.load(open(json_path))
except Exception:
    data = {}
try:
    log = open(log_path).read()
except OSError:
    log = ""

def strings_from(value):
    if isinstance(value, dict):
        if set(value.keys()) == {"string"}:
            yield value["string"]
        else:
            for item in value.values():
                yield from strings_from(item)
    elif isinstance(value, list):
        for item in value:
            yield from strings_from(item)

hardware = details.get("hardwareProperties", {})
props = details.get("deviceProperties", {})
name = props.get("name")
udid = hardware.get("udid")
product = hardware.get("marketingName") or hardware.get("productType")
os_version = props.get("osVersionNumber")
if name or udid:
    print(f"  {name or '?'} [{udid or '?'}] {product or '?'} iOS {os_version or '?'}")

messages = list(strings_from(data.get("error", {})))
messages.extend(line.strip() for line in log.splitlines())
seen = set()
for message in messages:
    lower = message.lower()
    if (
        "locked" in lower
        or "developer disk image" in lower
        or "unlock" in lower
    ) and message not in seen:
        seen.add(message)
        print("  " + message)
if any("locked" in message.lower() for message in messages):
    print("  Action: unlock the device, keep it awake, then rerun the deploy.")
PY
    STATUS=1
    continue
  fi

  python3 - "$DEVICE" "$JSON" "$LOG" <<'PY' || STATUS=1
import json
import sys

device_arg, json_path, log_path = sys.argv[1:]
with open(json_path) as f:
    data = json.load(f)

result = data.get("result", {})
hardware = result.get("hardwareProperties", {})
props = result.get("deviceProperties", {})
conn = result.get("connectionProperties", {})

name = props.get("name", device_arg)
udid = hardware.get("udid", "?")
product = hardware.get("marketingName") or hardware.get("productType", "?")
os_version = props.get("osVersionNumber", "?")
dev_mode = props.get("developerModeStatus", "?")
ddi = props.get("ddiServicesAvailable")
pairing = conn.get("pairingState", "?")
tunnel = conn.get("tunnelState", "?")

print(f"  {name} [{udid}] {product} iOS {os_version}")
print(f"  pairing={pairing} developerMode={dev_mode} tunnel={tunnel} ddiServicesAvailable={ddi}")

failures = []
if pairing != "paired":
    failures.append("device is not paired")
if dev_mode != "enabled":
    failures.append("Developer Mode is not enabled")
if ddi is not True:
    failures.append("developer disk image services are unavailable")

if failures:
    print("FAIL " + name + ": " + "; ".join(failures))
    try:
        log = open(log_path).read()
    except OSError:
        log = ""
    for line in log.splitlines():
        if "developer disk image" in line.lower() or "error:" in line.lower():
            print("  " + line.strip())
    sys.exit(1)

print("OK   " + name + " is deploy-ready")
PY
done

exit "$STATUS"
