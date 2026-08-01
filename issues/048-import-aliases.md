# 048 — Aliasy importów (+ string lokalny)

**Status:** ✅ zrobione (`import geom oso`, `import "path" [alias]`)
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

## Zakres MVP (zrobione)

- parser: opcjonalny alias po `import` (ident lub string) ✅
- `import "względna/ścieżka" [alias]` **lokalnie** (bez sieci) ✅
- testy + nota w [note/11](../note/11-biblioteki-klin.md) ✅

Implementacja: qualifier (alias lub domyślny = ostatni segment) kluczuje
`importAliases` i jest używany w źródle; mangling C używa realnej nazwy
`module`. Kolizja aliasu i alias będący słowem kluczowym C są odrzucane.
Węzeł `ImportSpec` w `lib/ast.dart`, parsowanie w `lib/parser.dart`
(`_importSpec`), resolucja/kluczowanie w `lib/project.dart`, round-trip w
`lib/fmt.dart`. Testy w `test/pipeline_test.dart` (issue 048).

## Poza zakresem

- fetch z GitHub / remote → [049](049-remote-imports.md)
- menedżer pakietów / lockfile
- artefakty SVD/IOC (`import "*.svd"`) → [053](053-device-board-assets.md)
