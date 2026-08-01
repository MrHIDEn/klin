# 065 — Lockfile projektu (`klin.lock` / sumy)

**Status:** ✅ zrobione
**Zależy od:** [049](049-remote-imports.md) (`klin.mod` już jest)

## Cel

Jak `go.sum` / `pubspec.lock`: commitowany plik z **dokładnymi** pinami
(commit SHA) i sumami integralności pobranych źródeł.

`klin.mod` (049) = żądane wersje (`require path ref`).  
`klin.lock` (065) = zamrożony wynik resolve + weryfikacja.

## Format

```text
klin lock 1
github/mrhiden/osa v0.1.0 <40-hex-commit> sha256:<64-hex>
```

- **version** — pin z `klin.mod` (tag / branch / ref użytkownika)
- **commit** — pełne SHA po `git rev-parse HEAD`
- **sha256** — hash zainstalowanych `.kl` (basename posortowany; `name\0`+bytes+`\0`)

Plik leży obok `klin.mod`. Cache pakietu ma też `.commit` obok `.pin`.

## Zachowanie

| Komenda | Sens |
|---|---|
| `klin get` | gdy wpis locka ma ten sam `version` co `klin.mod` → fetch po **commit SHA** + sprawdzenie hash |
| `klin get path@ref` | po udanym fetchu zapis / aktualizacja wpisu |
| `klin update` | force po pinie z moda (nie po SHA z locka) → przepisanie locka |

`klin run` / `test` nadal bez sieci i bez czytania locka (tylko cache).

## Checklista

- [x] parse / format `klin.lock`
- [x] generowanie przy `get` / `update`
- [x] `get` preferuje SHA z locka
- [x] weryfikacja sha256; błąd przy mismatch
- [x] e2e sieciowy (`osa@v0.1.0`) + testy jednostkowe hash/format
- [x] nota CLI / biblioteki

## Poza zakresem

- semver ranges, registry, prywatne git bez konfiguracji
- `klin upgrade` / outdated → [066](066-klin-upgrade-outdated.md)
