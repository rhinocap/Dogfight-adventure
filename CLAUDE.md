# Dogfight Adventures — Project Instructions

## Project overview
Browser-based fighter jet game. Single `index.html` file, pure Canvas + Web Audio API, no dependencies.

## Tech stack
- HTML5 Canvas for rendering
- Web Audio API for procedural sound
- Vanilla JavaScript (single file)
- No build tools, no frameworks, no external assets

---

## Who I am working with
Andrew Cunliffe — Staff-level designer/technologist at Intuit, Expert Platform (IEP/VEP).
Deep Figma expertise, comfortable with HTML/CSS/JS, shell scripting, Node.js. Systems thinker, IDS compliance focus.

---

## Working style — behavioral rules

### Full autonomy
- **Never ask for permission before acting.** Just do the work and report what was done.
- Never say "should I...?", "would you like me to...?", "shall I...?", or "want me to...?"
- Never present a plan and wait for approval — execute directly and report after.

### Test yourself before asking Andrew to test
- Always verify fixes work locally before pushing.
- Use Playwright, `node --check`, or whatever tool fits — never push and hope.
- If you can't test something, say so explicitly and explain why.

### Think through UX before building
- Before building any user-facing flow, reason through the complete journey end-to-end.
- Ask: "What does a brand new user actually have at this moment?"

### Terse communication
- Stop summarizing what you just did at the end of every response — Andrew can read the diff.
- Go straight to the point. Lead with the answer or action, not the reasoning.
- Short sessions get short retrospectives — no HTML report unless it was a big session.

### When Andrew returns after a gap (30+ min)
- Proactively surface: (1) where we left off, (2) what's pending/unblocked, (3) suggested next action.

### Minimize permission prompts
- File reads, edits, writes, bash commands, git operations — just do them.
- Only prompt for truly irreversible, high-blast-radius actions.

### Ask clarifying questions when ambiguous
- When any instruction is ambiguous (layout, behavior, visual), ask one clarifying question before writing code.

---

## Prompt coaching — always on

Before acting on any message, check for weak-prompt patterns. If matched, flag in one sentence and offer to proceed:

- "fix" with no description of what's wrong
- "it doesn't work" with no error or observed behavior
- "make it match the design" with no reference
- "it looks off" with no delta
- "I think the problem is X" when it's a guess (investigate instead of assuming)

---

## Coding rules

### No secrets in source code
- Never hardcode tokens, PATs, API keys, or credentials in source files.
- Use environment variables, dotfiles (`~/.my_token`), localStorage, or runtime user input.

### Token regeneration — check all consumers
- Check: source code, dotfiles, browser localStorage, Slack workflow URLs, launchd/cron, CI/CD.

### Check parent layout before touching spacing
- Before adding margin/padding, check the parent's display, flex-direction, and gap.
- If the parent has a large gap, wrap elements in a container with its own tighter gap.

### Rollback method
- Never use `git revert` alone if an auto-save hook is running.
- Always edit the file directly to remove unwanted code, then let the hook commit.

### IDS (Intuit Design System) compliance
- Every CSS value should use `var(--token, fallback)` — no bare hex, px, or font values.
- Buttons: `.btn .btn-primary` / `.btn .btn-secondary` — never inline button styles.
- Every interactive element must have a hover state.
- Icons: `stroke="currentColor"`, sized 14/16/20px.
- Probe for IDS tokens before hardcoding any design value.

### Canvas renderer rules
1. Always include `align-items:stretch;justify-content:flex-start;` in canvas body inline styles.
2. Always specify column widths — at least one `flex:1`, rest fixed px.
3. Scrollable zones: `flex:1;height:0;overflow-y:auto`.
4. Body fill: `flex:1;min-height:0` — never `height:100%` inside flex.
5. Inner flex rows: `width:100%;overflow:hidden`.

### Responsiveness
1. Proportional over fixed for layout columns.
2. Fixed px OK for component dimensions, not layout frames.
3. Flex scroll containers: always `flex:1;min-height:0`.
4. Two-panel layouts: one side fixed + `flex-shrink:0`, other side `flex:1;min-width:0`.
5. `min-width:0` on flex children that truncate.
6. `overflow:hidden;text-overflow:ellipsis;white-space:nowrap` on constrained single-line text.

---

## Git workflow
- Auto-save hook commits locally after every file edit but does NOT push.
- Push explicitly once per logical fix — after local tests pass.
- Never use `--no-verify` or `--no-gpg-sign`.
- `git revert` alone is ineffective with auto-save hooks — always edit files directly.
- Commit message: short imperative title, then body with what and why. End with `Co-Authored-By:`.

---

## Session logging
Update `conversations/YYYY-MM-DD.md` continuously — not just at end of session.
After every significant change, append what changed and why.
On terminal crash or context compaction: immediately write and push the session log.

---

## Testing rules
- **Comprehensive Playwright test suite** — committed to the repo, updated continuously as features change.
- Run the suite before every push.
- When a bug is found, add a regression test for it.
- Test files for throwaway one-off tests go in `/tmp/`. The persistent suite lives in the repo.

---

## Skills
See `.claude/skills/` for: revisit, regression-guard, session-log

---

## Strategy — Intuit context

### Big Bets
Primary: **BB2 — Connect People to Experts**

### Prioritization — Ladder of Impact
For every task, produce a quick ladder:
```
Task: [title]
- Problem: [who, what pain, why now]
- Ladder: Big Bet -> Outcome Goal -> Input Goal
- Score: Alignment/5 | Input Lift/5 | Time-to-Impact/5 | Customer/5 | Effort/5(rev) | Sequencing/5 -> Total/30
- Decision: Proceed / Defer / Reject
```

---

## Credential safety pattern
- `~/.figma_pat` — Figma personal access token
- `~/.iep_portal_pat` — GitHub Enterprise PAT
- `~/.iep-slack-webhook-url` — Slack webhook
- `~/.iep-slack-bot-token` — Slack bot token
- Never put webhook URLs or bot tokens in source code.

---

## Slack notifications
- Channel: `#iep-ai-native-preview-request-access`
- Andrew's Slack user ID: `W8FJ0JY83` (use `<@W8FJ0JY83>` to tag)
- Webhook URL stored in `~/.iep-slack-webhook-url`
- Slack mrkdwn: `*bold*`, `_italic_`, `<url|text>` for links

---

## Game controls

### Player 1 (Mouse)
- Mouse: move jet
- Left click (hold): machine gun
- Right click: missile
- Q/E: barrel roll left/right

### Player 2 (Keyboard)
- WASD: move jet
- Space (hold): machine gun
- F: missile
- R/T: barrel roll left/right

### Shared
- P: pause
- Space or Click: start game / retry
