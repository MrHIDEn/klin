# 016 — Interpolowane napisy

**Status:** 💭 do rozważenia
**Zależy od:** sensowny typ/`str` (ew. 012), nie blokuje kolejki głównej

## Kontekst

Dziś napisy to literały C + FFI (`puts`, `printf("%d\n", x)`). V ma `"hello $name"` / `'…${expr}…'`.

Inspiracje (składnia / formatowanie, nie kopiowanie runtime):

| Źródło | Co brać pod uwagę |
|---|---|
| **Dart** | `$name`, `${expr}`, interpolacja w stringu |
| **C#** | `$"…"`, `{expr}`, format `{expr:format}` |
| **C / printf** | specyfikatory `%d`, `%f`, `%.2f` — znane, tanie w emisji do C |

## Propozycja (później)

Składnia w stylu Dart/V + opcjonalny format (jak C# / printf):

```
let wartosc = 42
let suma = 100
puts("Zrobione $wartosc / $suma")
puts("Zrobione $wartosc / $suma. ${(wartosc * 100) / suma:0.##}")
```

### Format po `:`

Do decyzji (mogą współistnieć albo wybrać jeden styl):

1. **Styl printf** — jawny i 1:1 z emisją C:
   - `${x:%d}`, `${f:%.2f}`, `${p:%p}`
2. **Styl „maski”** (bliżej C# / Excel):
   - `0.##` — do 2 miejsc po przecinku, **końcowe zera opcjonalne**
   - `0.00` / `0.000` — **dokładnie** 2 / 3 miejsca (z zerami)
   - unikać mylących form w stylu `0.#3` (nieczytelne; lepiej `0.###` = do 3 opcjonalnych)

Przykłady maski:

| Mask | Sens |
|---|---|
| `0.##` | ułamkowe, max 2 cyfry, bez zbędnych zer |
| `0.00` | zawsze 2 miejsca |
| `0.000` | zawsze 3 miejsca |
| `0.###` | max 3 miejsca opcjonalne |

### Emisja

Bez ukrytej alokacji — preferencja: rozwinięcie do `printf` / `snprintf` z **jawnym buforem** (albo API z alokatorem). Freestanding: albo brak interpolacji, albo tylko wariant z buforem użytkownika.

**Test zasady nadrzędnej:** jeśli interpolacja wymaga ukrytego `malloc`, wypada albo staje się jawnym API z alokatorem.

## Czego nie robić teraz

- Nie dodawać cukru przed działającym modelem stringów / I/O (012).
- Nie obiecywać pełnego bogactwa `String.Format` / ICU bez decyzji o koszcie i bare-metalu.
