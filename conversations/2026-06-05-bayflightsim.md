# Session: 2026-06-05 — Bay Area flight sim (per-instance: bayflightsim)

## Goal
Rebuild ~/projects/dogfight-adventures as an iPad SF Bay Area flight sim in
Swift/SceneKit. Flight + dogfighting MVP. Build CPU <=20% of M5 Max. Deploy/test
on declan-ipad / declan-iphone via Tailscale.

## This session
### Built native iPad SceneKit game (fresh)
**What:** Wiped old browser canvas game. Wrote 9 Swift files (app, game loop,
procedural Bay world + landmarks, arcade flight model, enemy AI, weapons, touch
HUD, math). Generated .xcodeproj via Ruby xcodeproj gem + shared scheme.
**Why:** Goal = native iPad flight/combat game.
**Verified:** BUILD SUCCEEDED (sim + generic arm64 device). Ran on iPad Pro M5
simulator — renders Bay terrain, Golden Gate, jet + exhaust, live HUD, controls;
consecutive frames differ (flight is live); 4 bandits spawn.
**Pushed:** committed local 8824bd6 (branch first-person-3d), not pushed.

### CPU cap
**What:** build.sh runs nice -n 15 + -jobs 3 (3/18 cores = 16.7% ceiling).
Measured clean build: ~6% peak / ~2% mean of full machine. Under 20%. PASS.

## Blocker (carried forward)
- Device deploy to declan-ipad/iphone: devices are Tailscale-reachable (ping OK)
  but NOT paired with this Mac (devicectl lists only Andrew's 17 Pro + Watch).
  iOS install needs a lockdown pairing/trust record, which Tailscale IP can't
  provide. Needs one-time USB "Trust This Computer" on the device, then
  `bash scripts/deploy.sh declan-ipad`. Signed arm64 build is ready.

## State at end of session
- Game code: complete, compiles, runs on simulator ✓
- 20% CPU build cap: satisfied ✓
- On-device deploy: BLOCKED on device pairing (external, needs physical Trust tap)
