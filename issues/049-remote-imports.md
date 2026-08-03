# 049 — Remote imports (GitHub / path like Go)

**Status:** ✅ done (MVP)
**Depends on:** [048](048-import-aliases.md), [020](020-klin-libraries.md), [047](047-directory-modules.md);
e2e fixture: [063](063-remote-fixture-osa.md) (`github/klin-lang/osa`, tag `v0.1.0`)

## Syntax

```klin
import "github/klin-lang/osa"       // qualifier = osa
import "github/klin-lang/osa" oso   // qualifier = oso
import "gitlab/owner/repo"        // second allowed host
```

## MVP behavior

- Remote **only** when the first segment is `github` or `gitlab` (3 segments: `host/owner/repo`).
- Other `import "…"` = local (048).
- Hosts reserved — local directory `github/` does **not** shadow remote.
- **`klin run` / `test` without network:** package from cache or error + `klin get …`.
- Cache: `$KLIN_CACHE` or `~/.klin/pkg/<host>/<owner>/<repo>/` + `.pin`.
- Project manifest: **`klin.mod`** (like `go.mod` / `v.mod`):

```text
klin 1
require github/klin-lang/osa v0.1.0
```

| Command | Meaning |
|---|---|
| `klin get path[@ref]` | fetch; without `@ref` and without entry → latest + write `klin.mod` |
| `klin get` | install all `require` from `klin.mod` |
| `klin update [path[@ref]…]` | force re-fetch (no args = all from mod) |

After fetch: package directory as in [047](047-directory-modules.md).

## Checklist

- [x] recognize `github` / `gitlab`
- [x] cache + error without `klin get`
- [x] `klin.mod` + get/update
- [x] e2e offline (preseed) + network `osa@v0.1.0`
- [x] CLI / libraries note

## Later

- lock/checksums → [065](065-project-lockfile.md) ✅
- `klin upgrade` / outdated → [066](066-klin-upgrade-outdated.md) ✅
- Homebrew for compiler → [067](067-homebrew.md) ✅
- SVD artifacts → [053](053-device-board-assets.md)
