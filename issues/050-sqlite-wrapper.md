# 050 — Opakowanie SQLite w module Klin

**Status:** 💭 do rozważenia (niski priorytet — nieblokujące)
**Zależy od:** [021](021-biblioteki-c.md); mile [020](020-biblioteki-klin.md) / [047](047-directory-modules.md)

## Kontekst

SQLite zostaje biblioteką **C**. Klin może dać cienki moduł (`import sqlite`)
z `@[cimport]` / `@[cinclude]` / `@[link]` — nie portować silnika do Klina.

## Szkic (później)

- pakiet `sqlite/` lub `sqlite.kl`: deklaracje FFI + `pub` API (open / exec / …)
- link `-lsqlite3` albo amalgamation `.c` przez `@[link]`
- przykład host; bare-metal tylko z jawnym VFS/FS (poza MVP tego issue)

Alokacja SQLite = kontrakt C (jawny), nie ukryta magia Klina.

## Poza zakresem

- przepisanie SQLite w Klinie
- ORM / typed repo / query builder → [070](070-host-orm-sqlite.md) (host, niski priorytet)
- priorytet względem rdzenia języka / embedded LED / FFI podstaw
