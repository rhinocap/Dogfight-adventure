#!/bin/bash
#
# CPU-capped build for Dogfight Adventures.
#
# The M5 Max has 18 cores; the project goal caps build CPU at 20% (~3.6 cores).
# We hold xcodebuild to 3 concurrent jobs and run it at low priority (nice),
# which keeps sustained usage comfortably under the cap. Pass a -destination
# string as $1 (defaults to the iPad Pro M5 simulator).
#
set -euo pipefail
cd "$(dirname "$0")/.."

DEST="${1:-platform=iOS Simulator,name=iPad Pro 11-inch (M5)}"
JOBS=3
CONFIG="${CONFIG:-Debug}"
EXTRA=("${@:2}")
# Safe expansion of a possibly-empty array under `set -u` (bash 3.2).
EXTRA_SAFE=(${EXTRA[@]+"${EXTRA[@]}"})

echo "▶︎ Building (jobs=$JOBS, nice=15) for: $DEST"

nice -n 15 xcodebuild \
  -project DogfightAdventures.xcodeproj \
  -scheme DogfightAdventures \
  -configuration "$CONFIG" \
  -destination "$DEST" \
  -derivedDataPath build/DerivedData \
  -jobs "$JOBS" \
  COMPILER_INDEX_STORE_ENABLE=NO \
  ${EXTRA_SAFE[@]+"${EXTRA_SAFE[@]}"} \
  build
