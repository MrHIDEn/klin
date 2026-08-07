# 091 — Source maps through SVD fluent rewrite (`$device`)

**Status:** ✅
**Depends on:** 086 (SourceMap), 027 / `$device`

## Goal

Keep [`SourceMap`](../lib/source_map.dart) valid after `rewriteSvdFluent` so LSP
nav/diagnostics stay accurate in files that use `$device` /
`$peripherals_from_svd`.

## Done

- `rewriteSvdFluentWithMap` tracks mid-text offsets; preprocess composes them
  with the `$fn`/`$device` stage-1 map
- `analyzeSource` keeps `positionsSkewed: false` for `$device` + fluent samples
- Tests in `test/source_map_test.dart`
- Fluent `PreprocessError` positions remapped through the stage-1 map to the
  editor buffer

## Out of scope

- Parse recovery, rename, grammar highlight

## Completion criteria

- [x] Fluent rewrite preserves or rebuilds offset map
- [x] `analyzeSource` keeps nav enabled for `$device` samples
- [x] Tests for a small SVD/fluent fixture
- [x] Fluent preprocess errors remap to editor coordinates
