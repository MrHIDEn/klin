# 092 — Lex/parse multi-error recovery + workspace index

**Status:** ✅ parse recovery MVP (workspace index deferred)
**Depends on:** 086

## Goal

Recover from lex/parse errors so the LSP can report more than the first
syntax failure, and optionally maintain a lightweight workspace index for
faster cross-file queries.

Check-phase already collects per function. This issue adds **parse** recovery
at declaration / statement boundaries (`Parser(collectErrors: true)`).

## Done

- `ParseErrors` + `Parser(collectErrors:)` with sync at decl / stmt boundaries
- `analyzeSource` surfaces multiple parse diagnostics and keeps a partial
  `program` for check / nav when possible
- With LSP `sourceOverlay`, open-buffer `ParseError` from `loadProject`
  falls through to the recovering single-file path (imports stay fail-fast)
- Partial AST does not overwrite LSP `lastGood`; completion prefers fallback
  when `hasParseErrors`
- CLI / default `Parser()` remain fail-fast (first `ParseError`)
- Tests in `test/analyze_test.dart`

## Deferred

- Lex recovery (unexpected char etc.) — still fail-fast at lex
- Workspace symbol index (design/stub) — separate follow-up

## Out of scope

- Changing CLI fail-fast behaviour for `klin run` (kept)
- Full IDE project model / file watcher service

## Completion criteria

- [x] Parser recovery at declaration / statement boundaries (MVP)
- [x] Multiple lex/parse diagnostics in `analyzeSource` (parse; lex still single)
- [ ] Optional workspace symbol index design doc or stub — deferred
- [x] Tests
