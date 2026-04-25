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
Andrew Cunliffe — Staff-level designer/technologist. Deep Figma expertise, comfortable with HTML/CSS/JS, shell scripting, Node.js. Systems thinker.

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

### Design craft — Jony Ive level
- All UIs must be visually polished: generous whitespace, clear hierarchy, refined typography, elegant interactions.
- No bare modals, no cramped layouts, no floating buttons without context.
- Before shipping any UI, ask: "Would this embarrass Apple's design team?" If yes, iterate.

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

### Rollback method
- Never use `git revert` alone if an auto-save hook is running.
- Always edit the file directly to remove unwanted code, then let the hook commit.

### Check parent layout before touching spacing
- Before adding margin/padding, check the parent's display, flex-direction, and gap.
- If the parent has a large gap, wrap elements in a container with its own tighter gap.

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
- Delete feature branches immediately after merging.
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

## Revisit system

When Andrew says "Revisit", run the full audit:
1. Audit session log for mistakes, wrong-first-approaches
2. Classify: autonomy gap, accuracy gap, speed gap, comm gap, missing info gap
3. Build rules from each mistake -> CLAUDE.md, skills, or memory
4. Update `conversations/metrics.md`
5. Update `conversations/ideas-and-innovations.md`
6. Identify what Andrew can provide upfront next time
7. Report back with metrics, lessons, strategy-scored backlog
8. Size report to session — short session = short text, big session = full HTML report

---

## Metrics tracking

Tracked in `conversations/metrics.md`:
| Metric | Target |
|--------|--------|
| First-attempt accuracy | 90% |
| Push rejections | 0 |
| Autonomy score | 90% |
| Round-trips per task | 1 |
| Tests passing | 100% |
| Log currency | Immediate |

---

## Skills
See `.claude/skills/` for: revisit, regression-guard, session-log, playwright-tests, d4d

---

## Design for Delight (D4D) — customer empathy framework

### Customer Problem Statement
```
- I am [narrow description of the customer/persona]
- I am trying to [desired outcome]
- But [problem/barrier]
- Because [root cause]
- Which makes me feel [emotion]
```

### Hypothesis Statement
```
We believe that [solution/approach] for [customer/segment] will [customer benefit/outcome].
We'll know this is true when [signal/metric] moves to [target] by [timeframe].
```

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
