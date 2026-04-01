---
name: playwright-tests
description: Maintain comprehensive Playwright test suite — update continuously as features change
---
# playwright-tests — Living Test Suite

## When to run
- Before every push
- After adding/changing any game feature
- When a bug is found (add regression test)

## Steps

1. **Check if test suite exists** in repo (e.g. `tests/game.spec.js`)
2. If not, create initial suite covering:
   - Page loads without console errors
   - Canvas element exists and renders
   - Title screen appears on load
   - Click starts the game (transitions to TAKEOFF state)
   - Takeoff sequence completes and transitions to WAVE_INTRO
   - Player jet renders at expected position
   - Mouse movement updates player position
   - Left click fires bullets
   - Right click fires missiles
   - Q/E triggers barrel roll
   - P pauses/unpauses
   - Enemies spawn during waves
   - Collision detection works (bullets hit enemies)
   - Power-ups can be collected
   - Game over screen appears when HP reaches 0
   - High score saves to localStorage
   - Boss appears on wave 5
3. **After each feature change**, update or add relevant tests
4. **Run suite**: `npx playwright test`
5. **Report** results — all must pass before push
6. **Test files live in the repo** (not /tmp/) so they persist across sessions
