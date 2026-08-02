# 063 — Public fixture library `osa` (remote import)

**Status:** ✅ done
**Depends on:** [047](047-directory-modules.md) (directory = module)
**Consumed by:** [049](049-remote-imports.md)

## Goal

Separate, **public** GitHub repository with a minimal Klin package —
stable source for e2e / `import "github/mrhiden/osa"` examples and
`klin get` / `update` (049). Not part of Klin stdlib.

| | |
|---|---|
| Repo | https://github.com/MrHIDEn/osa |
| Import path | `github/mrhiden/osa` |
| Form | package directory `osa/*.kl` (as in 047) |
| Dependencies | none (pure Klin, no FFI) |
| License | MIT |
| MVP pin | git tag `v0.1.0` (`version()` = `1`) |

## Layout

```text
osa/                 # repo root
  README.md
  LICENSE
  osa/
    version.kl       # module osa — pub fn version(): i32
    math.kl          # module osa — pub fn add / clamp
    math_test.kl     # *_test.kl — skipped on import (047)
```

## API (`v0.1.0`)

| Symbol | Meaning |
|---|---|
| `version(): i32` | package version (`1` at `v0.1.0`) |
| `add(a, b): i32` | sum |
| `clamp(v, lo, hi): i32` | clamp to `[lo, hi]` |

## Versioning

- Tag `v0.1.0` = MVP above
- Later `v0.2.0` with `version()` → `2` only for `klin update` test (049)
- No registry — git tags only

## Checklist

- [x] public repo `MrHIDEn/osa`
- [x] content (README, LICENSE, `osa/*.kl`) on `main`
- [x] tag `v0.1.0` pushed
- [x] this issue + entry in [sorted.md](sorted.md) + link in [049](049-remote-imports.md)

## Out of scope

- `klin get` / lockfile implementation → [049](049-remote-imports.md)
- GitLab mirror
- `osa` copy as sole source of truth in Klin monorepo
