---
name: pmain
description: >
  Skrót "pmain" = zsynchronizuj lokalny `main` z origin. Użyj, gdy użytkownik
  napisze "pmain", "sync main", "pull main" albo gdy trzeba odświeżyć `main`
  przed założeniem nowego brancha feature/fix.
---

# pmain — sync / pull `main`

Gdy pojawi się `pmain` (lub "sync main" / "pull main"), wykonaj:

```sh
git checkout main
git pull origin main
```

## Zasady

- To operacja tylko na `main`: przełącz się na `main` i pociągnij z `origin`.
- NIE commituj na `main` (zasada repo) — `pmain` służy wyłącznie do
  aktualizacji, nie do pracy. Właściwą pracę rób na nowym branchu
  `cursor/<opis>-...` założonym od świeżego `main`.
- Sieć: przy błędach `git pull` ponów z backoffem (4s, 8s, 16s, 32s).
- Po `pmain` zwykle następuje: `git checkout -b cursor/<opis>-...` i dopiero
  potem zmiany.

## Kiedy używać

- Na starcie zadania, przed założeniem brancha (świeży punkt wyjścia).
- Po scaleniu PR-a, by zaciągnąć zmiany do lokalnego `main`.
- Gdy użytkownik prosi wprost ("pmain" / "sync main" / "pull main").
