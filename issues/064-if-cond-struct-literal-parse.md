# 064 — Warunek kończący się gołą nazwą mylony z literałem struktury

**Status:** ✅ zrobione
**Zależy od:** —

(Numer: wcześniej kolizja z [063](063-remote-fixture-osa.md) fixture `osa` — ten bug = **064**.)

## Objaw (naprawione)

Warunek `if`/`while`/`for …..<end`, który kończy się gołą nazwą tuż przed `{`,
był błędnie parsowany jako literał struktury (`nazwa { … }`):

```klin
fn main() {
    let a: i32 = 1
    let b: i32 = 2
    if a < b {          // OK: nawiasy opcjonalne
        puts("less")
    }
    if (a < b) {        // też OK
        puts("paren")
    }
}
```

## Przyczyna

W [`lib/parser.dart`](../lib/parser.dart) `_primary` traktuje `ident {` jako
literał struktury, gdy `_noStructLit == false`. `match` już tłumił literały
w nagłówku; `if`/`while` (i koniec `for …..<`) — nie.

## Naprawa

`_headerExpr()` (`_noStructLit = true`) wokół warunków `if`/`while`, końca
zakresu `for i in ..<end` oraz prawej strony post `for`. Literał struktury w
warunku nadal możliwy w nawiasach: `if (Foo{...}).x { … }` (nawias zeruje flagę).

## Kryteria

- [x] `if a < b { … }` / `while a < b { … }` / `for i in 0..<n { … }`
- [x] `if (cond) { … }` nadal działa (nawiasy opcjonalne)
- [x] `if (Point{ x: 3 }).x > 0 { … }` — literał w nawiasach
- [x] goldeny: `test/if_cond_bare_name.kl`, `test/if_cond_struct_paren.kl`

## Kontekst

Wykryte przy [017](017-collection-methods.md) i przy fixture [063](063-remote-fixture-osa.md)
(`clamp`: `if v < lo {`).
