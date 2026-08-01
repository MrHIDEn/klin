# 049 — Importy zdalne (GitHub / path jak Go)

**Status:** ✅ zrobione (MVP)
**Zależy od:** [048](048-import-aliases.md), [020](020-biblioteki-klin.md), [047](047-directory-modules.md);
fixture e2e: [063](063-remote-fixture-osa.md) (`github/mrhiden/osa`, tag `v0.1.0`)

## Składnia

```klin
import "github/mrhiden/osa"       // qualifier = osa
import "github/mrhiden/osa" oso   // qualifier = oso
import "gitlab/owner/repo"        // drugi dozwolony host
```

## Zachowanie MVP

- Remote **tylko** gdy pierwszy segment to `github` lub `gitlab` (3 segmenty: `host/owner/repo`).
- Inne `import "…"` = lokalne (048).
- Hosty zarezerwowane — lokalny katalog `github/` **nie** cieniuje remote.
- **`klin run` / `test` bez sieci:** pakiet z cache albo błąd + `klin get …`.
- Cache: `$KLIN_CACHE` lub `~/.klin/pkg/<host>/<owner>/<repo>/` + `.pin`.
- Manifest projektu: **`klin.mod`** (jak `go.mod` / `v.mod`):

```text
klin 1
require github/mrhiden/osa v0.1.0
```

| Komenda | Sens |
|---|---|
| `klin get path[@ref]` | pobierz; bez `@ref` i bez wpisu → najnowsza + zapis `klin.mod` |
| `klin get` | zainstaluj wszystkie `require` z `klin.mod` |
| `klin update [path[@ref]…]` | force ponowne pobranie (bez args = wszystkie z mod) |

Po pobraniu: katalog-pakiet jak [047](047-directory-modules.md).

## Checklista

- [x] rozpoznanie `github` / `gitlab`
- [x] cache + błąd bez `klin get`
- [x] `klin.mod` + get/update
- [x] e2e offline (preseed) + sieciowy `osa@v0.1.0`
- [x] nota CLI / biblioteki

## Później

- lock/sumy → [065](065-project-lockfile.md) ✅
- `klin upgrade` / outdated → [066](066-klin-upgrade-outdated.md)
- Homebrew kompilatora → [067](067-homebrew.md)
- artefakty SVD → [053](053-device-board-assets.md)
