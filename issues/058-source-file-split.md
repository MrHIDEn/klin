# 058 — Podział dużych plików źródłowych kompilatora

**Status:** 💭 do rozważenia (dług techniczny / utrzymywalność)
**Zależy od:** —

## Obserwacja

Kilka plików w [`lib/`](../lib/) mocno urosło (stan bieżący):

| Plik | Linie |
|---|---|
| [`lib/checker.dart`](../lib/checker.dart) | ~2116 |
| [`lib/emit_c.dart`](../lib/emit_c.dart) | ~1931 |
| [`lib/parser.dart`](../lib/parser.dart) | ~1373 |
| [`lib/ast.dart`](../lib/ast.dart) | ~806 |

Razem `lib/` ma ~8,4 tys. linii, z czego trzy pliki to grubo ponad połowa.
Duże pliki utrudniają nawigację, review i lokalne zmiany (każda faza issue
dotyka tych samych 3–4 plików), a switch-e po `sealed` typach robią się bardzo
długie.

## Czy to ma sens? — tak, ostrożnie

Podział poprawiłby utrzymywalność, ale to czysto **wewnętrzny refaktor**: nie
zmienia zachowania ani wygenerowanego C. Ryzyko głównie w rozjeżdżaniu się z
równoległymi zmianami (konflikty). Robić przyrostowo, przy okazji, nie jako
jeden wielki PR.

## Możliwe kierunki (szkic, do decyzji przy realizacji)

Dart wspiera `part` / `part of` (jeden `library`, wiele plików) oraz podział na
osobne biblioteki z `import`. Propozycje:

- `emit_c.dart` → np. `emit/expr.dart`, `emit/stmt.dart`, `emit/types.dart`
  (mangling / `_cType` / `_cDecl`), `emit/host.dart` (host-helpery `mem`/`time`),
  `emit/interp.dart` (interpolacja printf).
- `checker.dart` → np. `check/stmt.dart`, `check/expr.dart`, `check/types.dart`
  (rezolucja typów/modułów), `check/symbols.dart` (`_Scope` / `_Symbol`).
- `parser.dart` → np. `parse/decls.dart` (fn/struct/import), `parse/stmt.dart`,
  `parse/expr.dart`.
- `ast.dart` → ewentualnie `ast/stmt.dart`, `ast/expr.dart`, `ast/decl.dart`
  (uwaga: `sealed` wymaga wszystkich podtypów w tej samej bibliotece — użyć
  `part`, nie osobnych `import`).

## Zasady / kryteria

- Zero zmian zachowania: `dart test` zielone przed i po każdym kroku,
  wygenerowany C identyczny (goldeny).
- `dart analyze` czysto.
- Podział po odpowiedzialności, nie mechaniczny „co N linii".
- `sealed` (Stmt/Expr/typy): trzymać podtypy w jednej bibliotece przez `part`.
- Przyrostowo, mały PR na plik/obszar; nie łączyć z refaktorem logiki.

## Poza zakresem

- Zmiany semantyki języka / emisji.
- Reorganizacja `stdlib/` (`.kl`) — to inny temat.
- Wprowadzanie nowych zależności / generatorów.
