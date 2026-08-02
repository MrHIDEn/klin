# 042 — Luxon/V format dialect (`yyyy-MM-dd`)

**Status:** 💭 under consideration
**Depends on:** [037](037-datetime-format.md)

## Context

MVP: `strftime` dialect (`%Y-%m-%d`) in `time.format` / `parse`. Tokens in the
Luxon / V style (`yyyy-MM-dd`, `HH:mm`) can be more readable — **only**
as a second dialect in the `time` API, never as a global interpolation slot.

## Proposal

- `time.format(buf, "yyyy-MM-dd", t)` or an explicit mode / separate fn
- same subset as today (UTC date/time); no locale-heavy tokens (041)
- reverse parse for this dialect

## What not to do

- `${t:yyyy-MM-dd}` / `${t:%Y-…}` in 016 — **not planned** (stays in 037).
- Replacing `strftime` without need — both dialects can coexist.
