# Skrót `:=` (`let mut`)

Issue: [055](../issues/055-short-decl.md).

## Składnia

```
name := expr          // ≡ let mut name = expr
name = expr           // przypisanie (bez zmian)
let name = expr       // niemutowalne (bez zmian)
let mut name = expr   // równoważne `:=`
```

W C-`for` init przyjmuje `=` albo `:=` (oba wprowadzają mutowalną
zmienną pętli):

```
for i := 0; i < n; i = i + 1 { … }
```

## Semantyka

Jak `let mut`: mutowalna lokalna z inicjalizatorem, dedukcja typu z
prawej strony. W emisji C nie ma `mut` — zostaje zwykła lokalna.

## Ograniczenia MVP

- brak adnotacji typu przy `:=` (`x: i32 := 1` — użyj `let mut x: i32 = 1`)
- `klin fmt` zachowuje `:=` w deklaracjach; w init C-`for` normalizuje do `=`

Przykład: [`examples/short_decl.kl`](../examples/short_decl.kl).
