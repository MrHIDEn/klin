# 006 — Modules

**Status:** ✅ done
**Depends on:** 005

## Scope

- multiple files
- `module nazwa` / `import`
- `pub` — without it the symbol is private (**within the module**; directory-package
  files from [047](047-directory-modules.md) share that namespace)
- module prefix in mangling
- `static` in C for private symbols

## Rationale

This answers the original problem: in C external names have default
external linkage and live in one flat namespace. Workarounds are
`static` and prefix conventions (`gtk_widget_show`, `sqlite3_open`).
Klin should do this for the programmer.

C23 still has no modules; C++ got them only in C++20.

## Decision

Explicit `pub`, not export by capital letter like Go — explicit beats
hidden naming convention.

## Note

[`docs/12-moduly.md`](../docs/12-moduly.md). Examples: [`examples/modules/`](../examples/modules/),
directory package: [`examples/pkg_geom/`](../examples/pkg_geom/).

## Completion criteria

- [x] project with 3 modules compiles to a single `.c`
- [x] symbol without `pub` unavailable from another module (compile error)
- [x] private symbols are `static` in output
