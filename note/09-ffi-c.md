# FFI C — deklaracje i link (issue 021)

Interop z C to **jawne deklaracje** w Klinie, nie parser nagłówków.

## Deklaracja

```klin
@[cinclude("<math.h>")]
@[cimport, codename("sqrt")]
fn sqrt(x: f64): f64
```

- `@[cimport]` — funkcja bez ciała; frontend sprawdza arity i typy
- `@[codename("…")]` — symbol C (inaczej mangling Klina)
- `@[cinclude("…")]` — `#include` w wyemitowanym `.c` (cudzysłów lub `<…>`)

## Host builtins

Bez deklaracji dozwolone są tylko **`puts`** i **`printf`** (varargs / historyczne
hello-world). Każda inna funkcja C wymaga `@[cimport]`.

## Link

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

## Kontrakt

FFI **nie** ukrywa alokacji ani ownership — to umowa użytkownika z kodem C.
Bare-metal: ta sama ścieżka deklaracji; inne liby (HAL → [031](../issues/031-biblioteki-hal.md)).
Jednostki `.s` → [022](../issues/022-biblioteki-asm.md).
