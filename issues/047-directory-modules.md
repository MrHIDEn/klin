# 047 — Directory = one module (like Go/V)

**Status:** ✅ done
**Depends on:** [006](006-modules.md), [020](020-klin-libraries.md)

## Context

Today one `.kl` file = one module (`import mathx` → `mathx.kl`).
Go/V: package = directory, many files in one namespace.

## MVP scope

- `import name` → `name.kl` **or** directory `name/*.kl` (both at once = error)
- files in `name/` must have `module name`
- `pub` as in 006: private by default (visible in package); `pub` = export on `import`
- entry: siblings with the same `module` are loaded too
- `*_test.kl` in package directory: **skipped** on load (like Go `_test.go`)
- search as in 020 (sibling / `lib/` / `-I` / `KLIN_PATH` / stdlib)
- one `.c`; example [`examples/pkg_geom/`](../examples/pkg_geom/)
- search note: [`docs/11-klin-libraries.md`](../docs/11-klin-libraries.md);
  modules: [`docs/12-modules.md`](../docs/12-modules.md)

## Out of scope

- nested `geom/vec/`, `import a.b`
- package manager / version manifest
- `*_test.kl` as a separate test package in directory (separate step)
- import aliases / `import "…"` → [048](048-import-aliases.md)
- remote imports (GitHub) → [049](049-remote-imports.md)
