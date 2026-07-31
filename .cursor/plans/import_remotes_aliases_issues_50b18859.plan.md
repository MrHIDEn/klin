---
name: Import remotes aliases issues
overview: "\"Dopisać do issues przyszłe importy ze stringiem/GitHub (jak Go) oraz aliasy; teraz tylko dokumentacja — implementacja aliasów lokalnych możliwa jako mały follow-up, GitHub później.\""
todos:
  - id: stub-048-049
    content: Utworzyć 048-import-aliases.md + 049-remote-imports.md
    status: completed
  - id: link-sorted
    content: Linki w 047/020 + sorted (+ note/11 krótko)
    status: completed
  - id: docs-pr
    content: Branch docs + PR
    status: completed
isProject: false
---

# Issues: string import / GitHub / aliasy

## Werdykt (teraz vs potem)

| Cecha | Kiedy | Dlaczego |
|---|---|---|
| **Aliasy lokalne** (`import geom oso` / `import geom as oso`) | **Potem, ale wcześnie** — osobne małe issue | Parser + `importAliases` już mapują qualifier → prawdziwy moduł (stem vs `module`); brakuje tylko składni rename. Bez sieci. |
| **`import "ścieżka"` lokalnie** | **Potem** (z aliasami albo tuż po) | Nowa składnia (string); resolucja vs `-I` / katalogi 047. |
| **`import "github/…"` + fetch** | **Później** | Cache, wersje, sieć, zaufanie, lockfile — jak `go.mod` / proxy; nie mieszać z 047. |

Dziś: tylko `import ident` ([`lib/parser.dart`](lib/parser.dart)). Częściowy „alias” już istnieje: `import file_a` przy `module real` → qualifier `file_a`, mangling `real_`.

**Nie implementować GitHub w tym kroku.** Tylko dopisać issues + linki.

## Proponowana składnia (locked w issue, nie w kodzie)

```klin
import "github/mrhiden/osa"       // qualifier domyślny = ostatni segment → osa
import "github/mrhiden/osa" oso   // qualifier = oso (alias)
import geom oso                   // alias lokalny (gdy zrobimy 048)
```

Domyślna nazwa z path = last path element (jak Go). `pub` / private bez zmian.

## Pliki do utworzenia / edycji

1. **[`issues/048-import-aliases.md`](issues/048-import-aliases.md)** — 💭  
   - `import name alias` (i ewent. `as`)  
   - lokalne ścieżki string opcjonalnie w tym samym issue albo tylko ident+alias  
   - zależy od 006/047  
   - poza: GitHub fetch  

2. **[`issues/049-remote-imports.md`](issues/049-remote-imports.md)** — 💭  
   - `import "github/…"` / hostowane ścieżki  
   - cache katalogu, wersjonowanie (szkic), brak ukrytej magii  
   - zależy od 048 (aliasy + string) + 020/047  
   - poza: pełny registry jak npm  

3. Aktualizacje:  
   - [`issues/047-directory-modules.md`](issues/047-directory-modules.md) — „Poza zakresem”: link 048/049  
   - [`issues/020-biblioteki-klin.md`](issues/020-biblioteki-klin.md) — krótki link  
   - [`issues/sorted.md`](issues/sorted.md) — 048, 049 w „do rozważenia”  
   - ewent. jedno zdanie w [`note/11-biblioteki-klin.md`](note/11-biblioteki-klin.md)

## Branch / PR

Mały docs-only: z `main` (lub po merge #38) branch `docs-import-future-issues` → commit → PR (bez rcfix kodu; opcjonalnie zbędne).

## Kryterium

- 048 + 049 istnieją; sorted + 047/020 wskazują „potem”
- Zero zmian parsera / GitHub fetch w tym PR
