# FFI C — import i export (issues 021 / 045)

Interop z C to **jawne deklaracje** w Klinie, nie parser nagłówków.

| Kierunek | Atrybuty | Example |
|---|---|---|
| **Import** C→Klin | `@[cimport]`, `@[cheader]`, `@[cinclude]`, `@[link]`, CLI `-l`/`-L` | [`examples/ffi_add/`](../examples/ffi_add/) |
| **Export** Klin→C | `@[cexport, codename("…")]`; sam `codename` = ISR | [`examples/cexport_add/`](../examples/cexport_add/), blink STM32 |

Issues: [021](../issues/021-biblioteki-c.md) (import/link), [045](../issues/045-cexport.md) (export).

## Import (C → Klin)

```klin
@[cinclude("<math.h>")]
@[cimport, codename("sqrt")]
fn sqrt(x: f64): f64
```

- `@[cimport]` — funkcja bez ciała; frontend sprawdza arity i typy; emituje prototyp C
- `@[cheader]` — z `cimport`: deklaracja jest w nagłówku (`cinclude`); **bez** prototypu w `.c`
  (potrzebne dla `static inline` z SVD / HAL)
- `@[codename("…")]` — symbol C (inaczej mangling Klina)
- `@[cinclude("…")]` — `#include` w wyemitowanym `.c` (cudzysłów lub `<…>`)

### Host builtins

Bez deklaracji dozwolone są tylko **`puts`** i **`printf`** (varargs / historyczne
hello-world). Każda inna funkcja C wymaga `@[cimport]`.

### Link

```klin
@[link("libadd.a")]          // ścieżka względem pliku .kl
@[link("-lm")]               // flaga linkera as-is
```

CLI (host `klin run` / `klin test`):

```sh
klin run -L/opt/lib -lfoo main.kl
```

`@[link]` + `-l` / `-L` trafiają do argv `gcc`/`clang`/`tcc`. Przy `--emit-c`
lista `@[link]` trafia też do `out/<base>.link` (Makefile bare-metal).

Przykład: [`examples/ffi_add/`](../examples/ffi_add/).

## Export (Klin → C)

```klin
@[cexport, codename("klin_add")]
fn add(a: i32, b: i32): i32 {
    return a + b
}
```

- `@[cexport]` — `fn` **z ciałem**; globalny symbol w emisji C (nie `static`)
- `@[codename("…")]` — **wymagane** razem z `cexport` (stabilna nazwa dla C)
- `@[codename]` **bez** `cexport` — nadal OK (ISR / startup), np. `@[codename("SysTick_Handler")]`
- Nie łączyć `cexport` z `cimport`

C woła wyeksportowaną funkcję po `codename`. Przykład:
[`examples/cexport_add/`](../examples/cexport_add/).

## Porównanie

| | Import | Export |
|---|---|---|
| Marker | `@[cimport]` | `@[cexport]` |
| Ciało w Klinie | nie | tak |
| Nazwa C | zwykle `@[codename]` | **wymagany** `@[codename]` |
| Typowy use | libc / `.a` / HAL | biblioteka Klin, ISR |

## Kontrakt

FFI **nie** ukrywa alokacji ani ownership — to umowa użytkownika z kodem C.
Bare-metal: ta sama ścieżka deklaracji; inne liby (HAL → [031](../issues/031-biblioteki-hal.md)).
Jednostki `.s` → [022](../issues/022-biblioteki-asm.md).
