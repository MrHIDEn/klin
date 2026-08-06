# 091 — Source maps through SVD fluent rewrite (`$device`)

**Status:** 💭 0%
**Depends on:** 086 (SourceMap), 027 / `$device`

## Goal

Keep [`SourceMap`](../lib/source_map.dart) valid after `rewriteSvdFluent` so LSP
nav/diagnostics stay accurate in files that use `$device` /
`$peripherals_from_svd`.

Today preprocess drops the map when fluent rewrite runs (`positionsSkewed`).

## Out of scope

- Parse recovery, rename, grammar highlight

## Completion criteria

- [ ] Fluent rewrite preserves or rebuilds offset map
- [ ] `analyzeSource` keeps nav enabled for `$device` samples
- [ ] Tests for a small SVD/fluent fixture
