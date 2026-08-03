# 065 — Project lockfile (`klin.lock` / checksums)

**Status:** ✅ done
**Depends on:** [049](049-remote-imports.md) (`klin.mod` already exists)

## Goal

Like `go.sum` / `pubspec.lock`: committed file with **exact** pins
(commit SHA) and integrity checksums of fetched sources.

`klin.mod` (049) = requested versions (`require path ref`).  
`klin.lock` (065) = frozen resolve result + verification.

## Format

```text
klin lock 1
github/klin-lang/osa v0.1.0 <40-hex-commit> sha256:<64-hex>
```

- **version** — pin from `klin.mod` (tag / branch / user ref)
- **commit** — full SHA after `git rev-parse HEAD`
- **sha256** — hash of installed `.kl` (sorted basename; `name\0`+bytes+`\0`)

File lives beside `klin.mod`. Package cache also has `.commit` beside `.pin`.

## Behavior

| Command | Meaning |
|---|---|
| `klin get` | when lock entry has same `version` as `klin.mod` → fetch by **commit SHA** + hash check |
| `klin get path@ref` | after successful fetch write / update entry |
| `klin update` | force by pin from mod (not by SHA from lock) → rewrite lock |

`klin run` / `test` still without network and without reading lock (cache only).

## Checklist

- [x] parse / format `klin.lock`
- [x] generation on `get` / `update`
- [x] `get` prefers SHA from lock
- [x] sha256 verification; error on mismatch
- [x] network e2e (`osa@v0.1.0`) + unit tests hash/format
- [x] CLI / libraries note

## Out of scope

- semver ranges, registry, private git without configuration
- `klin upgrade` / outdated → [066](066-klin-upgrade-outdated.md)
