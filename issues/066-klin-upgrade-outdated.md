# 066 — `klin upgrade` / checking for newer dependencies

**Status:** ✅ done
**Depends on:** [049](049-remote-imports.md), optionally [065](065-project-lockfile.md)

## Context

In 049: `klin update` = **refresh per existing pin** (or explicit `@ref`).
Here: commands that **look for a newer** version on the remote.

## Commands

| Command | Meaning |
|---|---|
| `klin outdated [path…]` | report: `klin.mod` vs latest tag/ref (`path\tcurrent\tlatest`) |
| `klin upgrade [path…]` | bump `require` to newer + fetch + `klin.lock` (like `go get -u`) |

- No arguments: all `require` entries from `klin.mod`.
- Paths **without** `@ref`.
- Semver (`vX.Y.Z` / `X.Y.Z`): upgrade only when latest **>** current.
- Other pin (e.g. `main`): different latest = candidate.
- `klin run` **still offline** — no silent “there is an update”.
- Intentional downgrade: `klin get path@oldRef` / `update`.

## Checklist

- [x] `outdated` + report format / “all packages up to date”
- [x] `upgrade` bump + force fetch + mod/lock write
- [x] semver comparison; test with fake resolver
- [x] e2e `osa@v0.1.0` (currently only tag → up to date)
- [x] CLI / library note

## Out of scope

- auto-upgrade in CI, semver policy UI, upgrading the compiler itself (→ [067](067-homebrew.md) / `brew upgrade`)
