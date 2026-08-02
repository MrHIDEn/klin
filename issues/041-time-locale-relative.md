# 041 — Date locale + relative strings

**Status:** 💭 under consideration
**Depends on:** [037](037-datetime-format.md)

## Context

MVP formatting = `strftime` without language-dependent names (`%A`, etc.) and without
relative strings (“2 days ago” / Luxon `toRelative`).

## Proposal

- day/month names for a chosen locale (explicit argument / constant — not
  global hidden state, if avoidable)
- `to_relative` → write into a user buffer (like `format`), not a heap `str`
- no `n3`-style number formats in dates (separate decision vs 016)

## What not to do

- Hidden allocation during formatting.
- Pulling in IANA (040) “on the side” when not necessary.
- `${t:…}` sugar in 016 interpolation.
