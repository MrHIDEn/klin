# Host ASM unit via `@[link]` (issue 022)

```sh
cd examples/asm_add
dart run ../../bin/klin.dart run main.kl
# → 5
```

`add.S` is a raw assembly unit (`.S` so the host cc can `#if` Apple vs ELF
symbol names). No Klin ASM DSL. Symbols use `@[cimport, codename("asm_add")]`.
Details: [docs/10-asm.md](../../docs/10-asm.md).
