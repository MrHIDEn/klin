# 026 — Preprocessor (`$…`, D3)

**Status:** ✅ ukończone
**Zależy od:** stabilny frontend (praktycznie po 010+)

## Cel

Implementacja decyzji D3 ([note/01-decyzje.md](../note/01-decyzje.md)): makra
czasu kompilacji, **nie** generyki w gramatyce.

## MVP

- `$fn name(param: type|name|str, …) { … }` — definicja (ciało jako tekst ze
  slotami `$param`)
- `$name(args…)` — wywołanie; expand **przed** lex/parse/check/emit
- `--emit-pp` → `out/<plik>.pp.kl` (podgląd rozwinięcia)
- błędy preprocessora z pozycją wywołania (`unknown macro`, zła arność, …)

Przykład (jak w D3, uproszczone `name` zamiast literału string):

```
$fn point(name: name, T: type) {
  struct $name { x: $T  y: $T }
  fn (p: $name) len_sq(): $T { return p.x * p.x + p.y * p.y }
}
$point(Vec2i, i32)
```

## Poza MVP

- pełny język szablonów / AST-quote jak Nelua
- `$peripherals_from_svd` → [027](027-svd-ergonomic-api.md)
- mapowanie pozycji checkerowych z powrotem do ciała makra

## Kryterium

- [x] proste makro generuje wyspecjalizowany AST (golden `macro_point.kl`)
- [x] `--emit-pp` zapisuje rozwinięte źródło
