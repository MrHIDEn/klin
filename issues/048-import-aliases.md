# 048 — Aliasy importów (+ string lokalny)

**Status:** 💭 do rozważenia
**Zależy od:** [006](006-moduly.md), [047](047-directory-modules.md)

## Kontekst

Dziś: `import geom` — qualifier = ident. Częściowy alias już istnieje
(`import file_a` przy `module real` → użycie `file_a.…`, mangling `real_`).
Brak jawnego rename oraz `import "…"`.

## Proponowana składnia

```klin
import geom oso                      // lokalny alias: qualifier = oso
import "path/to/osa"                 // string; domyślny qualifier = last segment
import "path/to/osa" oso             // string + alias
```

Resolucja ścieżek jak 020/047 (`lib/`, `-I`, `KLIN_PATH`, plik lub katalog).
`pub` / private bez zmian.

## Zakres MVP (gdy robione)

- parser: opcjonalny alias po `import`
- ewent. `import "względna/ścieżka"` **lokalnie** (bez sieci)
- testy + krótka nota w [note/11](../note/11-biblioteki-klin.md)

## Poza zakresem

- fetch z GitHub / remote → [049](049-remote-imports.md)
- menedżer pakietów / lockfile
