# 050 — SQLite wrapper in a Klin module

**Status:** 💭 under consideration (low priority — non-blocking)
**Depends on:** [021](021-biblioteki-c.md); nice to have [020](020-biblioteki-klin.md) / [047](047-directory-modules.md)

## Context

SQLite stays a **C** library. Klin can provide a thin module (`import sqlite`)
with `@[cimport]` / `@[cinclude]` / `@[link]` — do not port the engine to Klin.

## Sketch (later)

- package `sqlite/` or `sqlite.kl`: FFI declarations + `pub` API (open / exec / …)
- link `-lsqlite3` or amalgamation `.c` via `@[link]`
- host example; bare-metal only with explicit VFS/FS (out of MVP for this issue)

SQLite allocation = explicit C contract, not hidden Klin magic.

## Out of scope

- rewriting SQLite in Klin
- ORM / typed repo / query builder → [070](070-host-orm-sqlite.md) (host, low priority)
- priority relative to language core / embedded LED / basic FFI
