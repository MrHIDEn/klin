# 016 — Interpolowane napisy

**Status:** 💭 do rozważenia
**Zależy od:** sensowny typ/`str` (ew. 012), nie blokuje kolejki głównej

## Kontekst

Dziś napisy to literały C + FFI (`puts`, `printf("%d\n", x)`). V ma `"hello $name"` / `'…${expr}…'`.

## Propozycja (później)

Składnia w stylu V (albo węższym):

```
let name = "Klin"
puts("hello $name")
puts("n=${n + 1}")
```

Emisja: bez ukrytej alokacji — albo składanie przez `printf`/`snprintf` z jawnym buforem, albo zabronione na freestanding bez alokatora. **Test zasady nadrzędnej:** jeśli interpolacja wymaga ukrytego `malloc`, wypada albo staje się jawnym API z alokatorem.

## Czego nie robić teraz

- Nie dodawać cukru przed działającym modelem stringów / I/O (012).
- Nie obiecywać formatowania jak w Pythonie f-string bez decyzji o koszcie.
