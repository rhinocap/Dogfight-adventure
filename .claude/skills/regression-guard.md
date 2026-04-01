---
name: regression-guard
description: Pre-commit check — verify critical game functions, DOM IDs, and no console errors
---
# regression-guard — Pre-commit Verification

## When to run
Before every commit or push. Automatically check these items.

## Steps

1. **Verify index.html parses** — no syntax errors that would prevent load

2. **Check critical functions exist:**
   - `startGame`
   - `resetPlayer`
   - `update`
   - `render`
   - `gameLoop`
   - `drawBackground`
   - `drawRunway`
   - `drawPlayerJet`
   - `drawHUD`
   - `drawTitleScreen`
   - `drawGameOverScreen`
   - `firePlayerBullet`
   - `fireMissile`
   - `startBarrelRoll`
   - `updateBarrelRoll`
   - `updateTakeoff`
   - `drawTakeoffHUD`

3. **Check DOM IDs exist:**
   - `canvas#game`

4. **Check game states are complete:**
   - STATE.TITLE, STATE.PLAYING, STATE.PAUSED, STATE.GAMEOVER, STATE.WAVE_INTRO, STATE.BOSS_INTRO, STATE.TAKEOFF

5. **Check no hardcoded secrets** — grep for `ghp_`, API keys, tokens

6. **Report** any missing items before allowing commit
