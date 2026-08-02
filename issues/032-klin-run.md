# 032 — `klin run <file.kl>`

**Status:** ✅ done
**Depends on:** 001 (compile→run pipeline already exists)

## Goal

Convenient command like `go run` / `cargo run`:

```bash
klin run an-file.kl
```

immediately: parse → check → emit → cc → run (process stdout/stderr).

## Decision

- Subcommand **`run`** — explicit compile→run path.
- Bare `klin <file.kl>` remains **alias** of `run` (no deprecate for now).
- Flags: `--cc gcc|clang|tcc`; `--emit-c` as before (without running).
- `build` / `check` — later, not in this step.

## Completion criteria

- [x] `klin run test/hello.kl` prints expected output
- [x] bare `klin test/hello.kl` still works
- [x] `klin run` without file → usage, exit ≠ 0
