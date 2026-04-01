---
name: revisit
description: Full session retrospective — extract mistakes, build rules, update metrics and ideas
---
# revisit — Session Retrospective

## When to run
When Andrew types "Revisit" or at the end of a significant session.

## Steps

1. **Read the session log** (`conversations/YYYY-MM-DD.md`) — extract every place a fix took more than one attempt, every time Andrew had to correct you, every wrong assumption.

2. **Classify each mistake:**
   - **Accuracy gap** — wrong first output, wrong assumption, built the wrong thing
   - **Speed gap** — right direction but too many round-trips
   - **Comm gap** — misunderstood what Andrew wanted
   - **Autonomy gap** — Andrew did something you could have done yourself

3. **Build a rule from each mistake** — "What rule, if it existed before, would have prevented this?"

4. **Update metrics** in `conversations/metrics.md`

5. **Update ideas log** in `conversations/ideas-and-innovations.md`

6. **Identify what Andrew can provide upfront next time**

7. **Report back** in Revisit format:
   - Mistakes table with classification and new rules
   - Metrics snapshot
   - What went well
   - What to improve
   - Suggestions for Andrew

8. **Size the report to the session.** Short session = short text. Big session = full HTML report at `conversations/revisit-reports/YYYY-MM-DD.html` with gradient cover, card layout, IDS blue `#0077c5`.

9. **Commit everything** — session log, metrics, ideas log, any new rules or memory files.
