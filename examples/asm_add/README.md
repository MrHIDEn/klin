# Host ASM via `@[link]`

Link a host assembly unit into `klin run` without a Klin ASM DSL.

## What

`add.S` exposes `asm_add`; Klin imports it with `@[cimport, codename("asm_add")]`
and `@[link("add.S")]`.

## Why

Shows issue [022](../../issues/022-asm-libraries.md): raw `.S` on the host cc
include path / link line, with Apple vs ELF symbol names handled in the
assembly — not a Klin-owned assembler.

## How

```sh
cd examples/asm_add
dart run ../../bin/klin.dart run main.kl
# → 5
```

## Links

- [docs/10-asm.md](../../docs/10-asm.md)
- [issues/022](../../issues/022-asm-libraries.md)
