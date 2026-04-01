---
name: session-log
description: Maintain daily session log — update continuously after every significant change
---
# session-log — Daily Session Log Maintenance

## When to run
After every significant change. On context compaction or terminal timeout — immediately.

## Steps

1. **Check if today's log exists** at `conversations/YYYY-MM-DD.md`
2. If not, create it with the standard template
3. **Append** to `## This session` with:
   - `### [Task name]`
   - `**What:** [what was built or changed]`
   - `**Why:** [reason / what it fixes]`
   - `**Pushed:** [commit hash or "auto-committed"]`
4. On session end or crash, update `## State at end of session`
5. Push the log

## Template
```markdown
# Session: YYYY-MM-DD

## Where we left off
[1 sentence]

## This session
[entries appended here]

## Mistakes & lessons
| Mistake | Type | Rule added |
|---------|------|-----------|

## State at end of session
- [item]: [status]
- Pending:
  - [item]
```
