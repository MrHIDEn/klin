# 051 — Opakowanie JSON w module Klin (+ ścieżki `$…`)

**Status:** 💭 do rozważenia (niski priorytet — nieblokujące)
**Zależy od:** [021](021-biblioteki-c.md); mile [020](020-biblioteki-klin.md) / [047](047-directory-modules.md); ścieżki `$` → [026](026-preprocessor.md)

## Kontekst

JSON zostaje w bibliotece **C** (np. cJSON / yyjson / jansson). Klin może dać
cienki moduł (`import json`) z FFI — nie portować parsera do Klina.

Alokacja / ownership = kontrakt C (jawny). Bez ukrytego GC / map z JSON.

## Szkic A — wrapper FFI

- pakiet `json/` lub `json.kl`: `@[cinclude]` + `@[cimport]` + `@[link]`
- `pub` API: parse do uchwytu C, get string/int, free — bez cukru „object → dict”
- przykład host

## Szkic B — dostęp ścieżką przez `$` (opcjonalnie, później)

Ergonomia w stylu `$json_get(doc, a.b.c)` / podobne — **makro preprocessora**
([026](026-preprocessor.md)), które rozwija się do wywołań FFI (np. kolejne
`cJSON_GetObjectItem`), nie do magicznego typu runtime.

```klin
// szkic — nie składnia MVP:
let n = $json_path(root, user.profile.age)   // → jawne get’y C po expand
```

Wymaga ustalonego API wrappera (A) + makr ścieżkowych; zero ukrytej alokacji
w expandzie poza tym, co robi lib C.

## Poza zakresem

- natywny typ `json` / dynamiczne mapy w języku
- ORM / schema codegen z JSON Schema (osobna decyzja)
- priorytet względem rdzenia / embedded / FFI podstaw
