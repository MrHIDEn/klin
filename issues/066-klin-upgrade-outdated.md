# 066 — `klin upgrade` / sprawdzanie nowszych zależności

**Status:** ✅ zrobione
**Zależy od:** [049](049-remote-imports.md), mile [065](065-project-lockfile.md)

## Kontekst

W 049: `klin update` = **odśwież wg istniejącego pinu** (lub jawnego `@ref`).
Tu: komendy, które **szukają nowszej** wersji na remote.

## Komendy

| Komenda | Sens |
|---|---|
| `klin outdated [path…]` | raport: `klin.mod` vs najnowszy tag/ref (`path\tcurrent\tlatest`) |
| `klin upgrade [path…]` | bump `require` do nowszego + pobranie + `klin.lock` (jak `go get -u`) |

- Bez argumentów: wszystkie `require` z `klin.mod`.
- Ścieżki **bez** `@ref`.
- Semver (`vX.Y.Z` / `X.Y.Z`): upgrade tylko gdy latest **>** current.
- Inny pin (np. `main`): inny latest = kandydat.
- `klin run` **nadal bez sieci** — żadnego cichego „jest update”.
- Świadomy downgrade: `klin get path@staryRef` / `update`.

## Checklista

- [x] `outdated` + format raportu / „all packages up to date”
- [x] `upgrade` bump + force fetch + zapis moda/locka
- [x] porównywanie semver; test z fake resolverem
- [x] e2e `osa@v0.1.0` (aktualnie jedyny tag → up to date)
- [x] nota CLI / biblioteki

## Poza zakresem

- auto-upgrade przy CI, semver policy UI, upgrade samego kompilatora (→ [067](067-homebrew.md) / `brew upgrade`)
