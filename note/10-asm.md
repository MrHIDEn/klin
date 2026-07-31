# Jednostki ASM (issue 022)

Surowy `.s` / `.S` dołączany przez istniejące `@[link]` — **bez** DSL-a ASM
w Klinie.

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
