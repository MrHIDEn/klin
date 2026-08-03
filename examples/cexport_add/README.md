# Export Klin → C (`@[cexport]`)

Build a Klin library entry and call it from a C `main`.

## What

`lib.kl` exports `klin_add` via `@[cexport, codename("klin_add")]`. `--emit-h`
writes a C prototype; `caller.c` owns the process entry point.

## Why

Klin still requires a `main` in the `.kl` entry for the frontend; rename that
empty `main` in the emitted C so your C program is the real entry
([045](../../issues/045-cexport.md) / [046](../../issues/046-emit-h.md)).

## How

From **repo root**:

```sh
dart run bin/klin.dart --emit-c --emit-h examples/cexport_add/lib.kl
sed -i.bak 's/int main(void)/static int klin_lib_main(void)/g' out/lib.c
gcc -I out examples/cexport_add/caller.c out/lib.c -o out/add_demo
./out/add_demo
# → 5
```

Or from this directory (emit writes `out/` under CWD):

```sh
cd examples/cexport_add
dart run ../../bin/klin.dart --emit-c --emit-h lib.kl
sed -i.bak 's/int main(void)/static int klin_lib_main(void)/g' out/lib.c
gcc -I out caller.c out/lib.c -o add_demo
./add_demo
```

## Links

- [docs/09-ffi-c.md](../../docs/09-ffi-c.md)
- [issues/045](../../issues/045-cexport.md), [issues/046](../../issues/046-emit-h.md)
- ISR-style `@[codename]` alone: [`../stm32/`](../stm32/)
