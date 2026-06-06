#!/bin/bash
#
# Build (CPU-capped) + sign + install + launch on a paired iOS device.
# Usage: bash scripts/deploy.sh <device-name|udid>
#
# Signing is headless via an App Store Connect API key (no Xcode GUI token
# needed): it registers the device with the developer account, then xcodebuild
# mints a development provisioning profile. Requires:
#   - device paired + Developer Mode ON (iOS 16+)
#   - ~/.appstoreconnect/issuer.txt and ~/.appstoreconnect/private_keys/AuthKey_<KEYID>.p8
#
set -euo pipefail
cd "$(dirname "$0")/.."

ARG="${1:?usage: deploy.sh <device-name|udid>}"
BUNDLE="com.cunliffe.dogfightadventures"
TEAM="${DEVELOPMENT_TEAM:-8W34JFWLTB}"
KEYID="${ASC_KEY_ID:-7GLPKRQCL3}"
KEYPATH="$HOME/.appstoreconnect/private_keys/AuthKey_${KEYID}.p8"
ISSUER="$(cat "$HOME/.appstoreconnect/issuer.txt")"

# Resolve a UDID (accept a raw UDID, or look one up by device name).
xcrun devicectl list devices --json-output /tmp/devs_deploy.json >/dev/null 2>&1 || true
read -r UDID NAME < <(python3 - "$ARG" <<'PY'
import json,sys
arg=sys.argv[1]
try: d=json.load(open('/tmp/devs_deploy.json'))
except Exception: d={}
for dev in d.get('result',{}).get('devices',[]):
    hp=dev.get('hardwareProperties',{}); dp=dev.get('deviceProperties',{})
    u=hp.get('udid',''); n=dp.get('name','?')
    if arg in (u, n) or arg.lower() in n.lower():
        print(u, n); break
else:
    # Assume the argument is already a UDID.
    print(arg, arg)
PY
)
echo "▶︎ Target: $NAME [$UDID]"

echo "▶︎ Registering device with App Store Connect…"
node scripts/register_devices.mjs "$KEYID" "$NAME:$UDID"

echo "▶︎ Building (CPU-capped) + signing…"
nice -n 15 xcodebuild \
  -project DogfightAdventures.xcodeproj -scheme DogfightAdventures \
  -configuration Release -destination "id=$UDID" \
  -derivedDataPath build/DerivedData -jobs 3 \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$KEYPATH" -authenticationKeyID "$KEYID" -authenticationKeyIssuerID "$ISSUER" \
  DEVELOPMENT_TEAM="$TEAM" COMPILER_INDEX_STORE_ENABLE=NO build

APP=$(find build/DerivedData/Build/Products/Release-iphoneos -name "*.app" -maxdepth 2 | head -1)
echo "▶︎ Installing $APP"
xcrun devicectl device install app --device "$UDID" "$APP"
echo "▶︎ Launching…"
xcrun devicectl device process launch --device "$UDID" "$BUNDLE"
echo "✓ Launched on $NAME"
