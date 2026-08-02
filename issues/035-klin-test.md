# 035 — `klin test` (tests in Klin, like `go test`)

**Status:** ✅ done
**Depends on:** [032](032-klin-run.md) (`klin run`); `stdlib/testing`

## Goal

Tests for **programs in Klin** (not the compiler — that stays on `dart test`).

## MVP (done)

```bash
klin test                     # *_test.kl in cwd
klin test path/to/dir         # directory
klin test path/foo_test.kl    # single file
klin test --cc clang …
```

- files `*_test.kl`
- functions `fn test_*(…)` without parameters — runner injects `main` that calls them
  (optional own `main` instead of harness)
- `import testing` → `assert` / `assert_eq_i32` (`stdlib/testing.kl`)
- result: `ok` / `FAIL` + `PASS` or `FAIL n/m`, exit ≠ 0 on failure
- example: [`examples/add_test.kl`](../examples/add_test.kl)

## Outside MVP

- table-driven / subtests, benchmarks, coverage, bare-metal

## Criteria

- [x] `klin test examples/add_test.kl` green
- [x] assertion fail → exit ≠ 0 and message `FAIL: assert_eq_i32…`
- [x] documentation: Klin code vs compiler `dart test`
