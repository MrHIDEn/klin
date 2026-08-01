# 063 — Warunek kończący się gołą nazwą mylony z literałem struktury

**Status:** 🐞 do naprawy (parser)
**Zależy od:** —

## Objaw

Warunek `if`/`while`, który kończy się gołą nazwą tuż przed `{`, jest błędnie
parsowany jako literał struktury (`nazwa { … }`):

```klin
fn main() {
    let a: i32 = 1
    let b: i32 = 2
    if a < b {          // błąd: `b {` czytane jako literał struktury
        puts("less")
    }
}
```

Efekt: `oczekiwano `{`` (parser zjada blok jako ciało literału `b{...}`).

## Przyczyna

W [`lib/parser.dart`](../lib/parser.dart) `_primary` traktuje `ident {` jako
literał struktury, gdy `_noStructLit == false`. `match` ustawia
`_noStructLit = true` na czas nagłówka/wzorca, ale `_ifStmt` i `_whileStmt`
parsują warunek zwykłym `_expr()` bez tej flagi. Gdy warunek kończy się gołą
nazwą (`… < m`, `… == value`), `{` bloku jest brane za początek literału.

Obejścia działają, bo warunek nie kończy się gołą nazwą: `i < xs.len` (pole),
`pred(x)` (wywołanie), `x < xs[i]` (indeks), literał, `(…)`.

## Proponowana naprawa

Tłumić literały struktur w warunkach `if`/`while` — jak w `match`
(`_noStructLit = true` wokół parsowania warunku, przywrócić po). Literał
struktury w warunku nadal możliwy w nawiasach: `if (Foo{...}).x { … }`
(nawias resetuje `_noStructLit`).

## Kryteria

- `if a < b { … }` / `while a < b { … }` (goła nazwa po prawej) kompilują się.
- `match` bez zmian; goldeny zielone.
- Test: warunek kończący się nazwą + wariant z nawiasem dla literału struktury.

## Kontekst

Wykryte przy [017](017-collection-methods.md) (`min`/`max`/`contains` w
`slice_num_ops` — obejście: warunek kończy się indeksem `xs[i]`).
