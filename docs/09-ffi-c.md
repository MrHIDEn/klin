# C FFI — import and export (issues 021 / 045)

Interop with C is **explicit declarations** in Klin, not a header parser.

| Direction | Attributes | Example |
|---|---|---|
| **Import** C→Klin | `@[cimport]`, `@[cheader]`, `@[cinclude]`, `@[link]`, CLI `-l`/`-L` | [`examples/ffi_add/`](../examples/ffi_add/) |
| **Export** Klin→C | `@[cexport, codename("…")]`; `codename` alone = ISR | [`examples/cexport_add/`](../examples/cexport_add/), STM32 blink |

Issues: [021](../issues/021-c-libraries.md) (import/link), [045](../issues/045-cexport.md) (export).

## Import (C → Klin)

```klin
@[cinclude("<math.h>")]
@[cimport, codename("sqrt")]
fn sqrt(x: f64): f64
```

- `@[cimport]` — function without body; frontend checks arity and types; emits C prototype
- `@[cheader]` — with `cimport`: declaration is in header (`cinclude`); **no** prototype in `.c`
  (needed for `static inline` from SVD / HAL)
- `@[codename("…")]` — C symbol (otherwise Klin mangling)
- `@[cinclude("…")]` — `#include` in emitted `.c` (quoted or `<…>`)

### Host builtins

Without declarations only **`puts`** and **`printf`** are allowed (varargs / historical
hello-world). Every other C function requires `@[cimport]`.

### Link

```klin
@[link("libadd.a")]          // path relative to .kl file
@[link("-lm")]               // linker flag as-is
```

CLI (host `klin run` / `klin test`):

```sh
klin run -L/opt/lib -lfoo main.kl
```

`@[link]` + `-l` / `-L` go to `gcc`/`clang`/`tcc` argv. With `--emit-c`
the `@[link]` list also goes to `out/<base>.link` (bare-metal Makefile).
Paths also cover ASM units (`.s` / `.S`) — [docs/10-asm.md](10-asm.md),
[`examples/asm_add/`](../examples/asm_add/).

C example: [`examples/ffi_add/`](../examples/ffi_add/).

## Export (Klin → C)

```klin
@[cexport, codename("klin_add")]
fn add(a: i32, b: i32): i32 {
    return a + b
}
```

- `@[cexport]` — `fn` **with body**; global symbol in C emission (not `static`)
- `@[codename("…")]` — **required** with `cexport` (stable name for C)
- `@[codename]` **without** `cexport` — still OK (ISR / startup), e.g. `@[codename("SysTick_Handler")]`
- Do not combine `cexport` with `cimport`; do not apply `cexport` to `main`

C calls the exported function by `codename`. Prototypes:

```sh
klin --emit-h lib.kl                 # → out/lib.h
klin --emit-c --emit-h lib.kl        # .c + .h
```

Example: [`examples/cexport_add/`](../examples/cexport_add/). Issue:
[046](../issues/046-emit-h.md).

## Comparison

| | Import | Export |
|---|---|---|
| Marker | `@[cimport]` | `@[cexport]` |
| Body in Klin | no | yes |
| C name | usually `@[codename]` | **required** `@[codename]` |
| Typical use | libc / `.a` / HAL | Klin library, ISR |

## Contract

FFI **does not** hide allocation or ownership — that is the user's agreement with C code.
Bare-metal: same declaration path; other libs (HAL → [031](../issues/031-hal-libraries.md)).
`.s` units → [docs/10-asm.md](10-asm.md) / [022](../issues/022-asm-libraries.md).
