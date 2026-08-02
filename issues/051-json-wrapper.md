# 051 — JSON wrapper in a Klin module (+ `$…` paths)

**Status:** 💭 under consideration (low priority — non-blocking)
**Depends on:** [021](021-c-libraries.md); nice to have [020](020-klin-libraries.md) / [047](047-directory-modules.md); `$` paths → [026](026-preprocessor.md)

## Context

JSON stays in a **C** library (e.g. cJSON / yyjson / jansson). Klin can provide
a thin module (`import json`) with FFI — do not port the parser to Klin.

Allocation / ownership = explicit C contract. No hidden GC / maps from JSON.

## Sketch A — FFI wrapper

- package `json/` or `json.kl`: `@[cinclude]` + `@[cimport]` + `@[link]`
- `pub` API: parse to C handle, get string/int, free — no “object → dict” sugar
- host example

## Sketch B — path access via `$` (optional, later)

Ergonomics like `$json_get(doc, a.b.c)` / similar — **preprocessor macro**
([026](026-preprocessor.md)) that expands to FFI calls (e.g. successive
`cJSON_GetObjectItem`), not to a magic runtime type.

```klin
// sketch — not MVP syntax:
let n = $json_path(root, user.profile.age)   // → explicit C gets after expand
```

Requires a settled wrapper API (A) + path macros; zero hidden allocation
in the expand beyond what the C lib does.

## Out of scope

- native `json` type / dynamic maps in the language
- ORM / schema codegen from JSON Schema (separate decision)
- priority relative to core / embedded / basic FFI
