# Jednostki ASM (issue 022)

Surowy `.s` / `.S` dołączany przez istniejące `@[link]` — **bez** DSL-a ASM
w Klinie.

## `.s` vs `.S`

Konwencja toolchainów C (gcc/clang):

| Rozszerzenie | Preprocessor C | Sens |
|---|---|---|
| **`.s`** | nie | Plik idzie prosto do assemblera; `#if` / `#define` / `#include` nie działają (albo są zwykłym tekstem / błędem, zależnie od toola). |
| **`.S`** | tak (`cpp`, potem assembler) | Można pisać `#if defined(__APPLE__)`, `#define SYM _foo`, `#include`. |

W Klinie (`@[link]`) oba są OK — to tylko ścieżka dla `cc`. Wybór zależy od
tego, czy potrzebujesz preprocessora.

Przykład [`examples/asm_add/add.S`](../examples/asm_add/add.S) ma wielkie `.S`,
żeby ten sam plik obsługiwał Apple (`_asm_add`) vs ELF (`asm_add`) oraz
aarch64 vs x86_64 przez `#if`.

## Host

```klin
@[link("add.S")]
@[cimport, codename("asm_add")]
fn asm_add(a: i32, b: i32): i32
```

`klin run` przekazuje ścieżkę do host `cc` (jak `.a` / `.o`). Symbole:
Klin→ASM / C = `@[codename]` / `@[cexport]`; ASM→Klin = `@[cimport, codename]`.

Przykład: [`examples/asm_add/`](../examples/asm_add/).

## Bare-metal

`-T linker.ld` i `arm-none-eabi-*` zostają w Makefile. Klin przy `--emit-c`
zapisuje listę `@[link]` do `out/<base>.link`; Makefile linkuje te pliki
obok wyemitowanego `.c` (np. `startup.s` z blink STM32).

## Poza zakresem

ABI per target, mangling bez `codename`, assembler w `.kl`, CLI tylko pod ASM.
FFI C ogólnie: [09-ffi-c.md](09-ffi-c.md).
