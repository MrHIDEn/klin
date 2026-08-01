# 065 — Lockfile projektu (`klin.lock` / sumy)

**Status:** 💭 do rozważenia
**Zależy od:** [049](049-remote-imports.md) (`klin.mod` już jest)

## Cel

Jak `go.sum` / `pubspec.lock`: commitowany plik z **dokładnymi** pinami
(commit SHA) i opcjonalnie sumami integralności pobranych źródeł.

`klin.mod` (049) = żądane wersje (`require path ref`).  
`klin.lock` (065) = zamrożony wynik resolve + weryfikacja.

## Zakres (szkic)

- generowanie / aktualizacja przy `klin get` / `update`
- `klin get` preferuje SHA z locka gdy obecny
- diff widoczny w git; CI reprodukowalne bez „pływającego” `main`

## Poza zakresem

- semver ranges, registry, prywatne git bez konfiguracji
