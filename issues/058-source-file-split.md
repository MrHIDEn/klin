# 058 — Split large compiler source files

**Status:** 💭 under consideration (technical debt / maintainability)
**Depends on:** —

## Observation

Several files in [`lib/`](../lib/) have grown large (current state):

| File | Lines |
|---|---|
| [`lib/checker.dart`](../lib/checker.dart) | ~2116 |
| [`lib/emit_c.dart`](../lib/emit_c.dart) | ~1931 |
| [`lib/parser.dart`](../lib/parser.dart) | ~1373 |
| [`lib/ast.dart`](../lib/ast.dart) | ~806 |

Together `lib/` has ~8.4k lines, of which three files are well over half.
Large files hinder navigation, review, and local changes (every issue phase
touches the same 3–4 files), and `sealed` type switches get very
long.

## Does it make sense? — yes, carefully

Splitting would improve maintainability, but this is purely an **internal refactor**: no
behavior change or generated C change. Main risk is diverging from
parallel changes (conflicts). Do incrementally, opportunistically, not as
one big PR.

## Possible directions (sketch, decide at implementation)

Dart supports `part` / `part of` (one `library`, many files) and split into
separate libraries with `import`. Proposals:

- `emit_c.dart` → e.g. `emit/expr.dart`, `emit/stmt.dart`, `emit/types.dart`
  (mangling / `_cType` / `_cDecl`), `emit/host.dart` (host helpers `mem`/`time`),
  `emit/interp.dart` (printf interpolation).
- `checker.dart` → e.g. `check/stmt.dart`, `check/expr.dart`, `check/types.dart`
  (type/module resolution), `check/symbols.dart` (`_Scope` / `_Symbol`).
- `parser.dart` → e.g. `parse/decls.dart` (fn/struct/import), `parse/stmt.dart`,
  `parse/expr.dart`.
- `ast.dart` → possibly `ast/stmt.dart`, `ast/expr.dart`, `ast/decl.dart`
  (note: `sealed` requires all subtypes in the same library — use
  `part`, not separate `import`).

## Rules / criteria

- Zero behavior change: `dart test` green before and after each step,
  generated C identical (goldens).
- `dart analyze` clean.
- Split by responsibility, not mechanical “every N lines”.
- `sealed` (Stmt/Expr/types): keep subtypes in one library via `part`.
- Incrementally, small PR per file/area; do not combine with logic refactor.

## Out of scope

- Language semantics / emission changes.
- Reorganizing `stdlib/` (`.kl`) — different topic.
- Introducing new dependencies / generators.
