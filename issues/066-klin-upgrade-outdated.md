# 066 — `klin upgrade` / sprawdzanie nowszych zależności

**Status:** 💭 do rozważenia
**Zależy od:** [049](049-remote-imports.md)

## Kontekst

W 049: `klin update` = **odśwież wg istniejącego pinu** (lub jawnego `@ref`).
Brak komendy, która **szuka nowszej** wersji na remote.

## Propozycja

| Komenda | Sens |
|---|---|
| `klin outdated` | raport: `klin.mod` vs najnowszy tag/ref na hoście |
| `klin upgrade [path…]` | bump `require` do nowszego + pobranie (jak `go get -u`) |

- `klin run` **nadal bez sieci** — żadnego cichego „jest update”.
- Świadomy downgrade zostaje: `klin get path@staryRef` / `update`.

## Poza zakresem

- auto-upgrade przy CI, semver policy UI, upgrade samego kompilatora (→ [067](067-homebrew.md) / `brew upgrade`)
