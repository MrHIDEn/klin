# 092 — Lex/parse multi-error recovery + workspace index

**Status:** 💭 0%
**Depends on:** 086

## Goal

Recover from lex/parse errors so the LSP can report more than the first
syntax failure, and optionally maintain a lightweight workspace index for
faster cross-file queries.

Today: lex/parse remain fail-fast; check-phase already collects per function.

## Out of scope

- Changing CLI fail-fast behaviour for `klin run` (keep unless flagged)
- Full IDE project model / file watcher service

## Completion criteria

- [ ] Parser recovery at declaration / statement boundaries (MVP)
- [ ] Multiple lex/parse diagnostics in `analyzeSource`
- [ ] Optional workspace symbol index design doc or stub
- [ ] Tests
