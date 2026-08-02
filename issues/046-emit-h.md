# 046 — C header from exports (`--emit-h`)

**Status:** ✅ done
**Depends on:** [045](045-cexport.md)

## Context

After `@[cexport, codename]` C calls Klin symbols; `--emit-h` generates a header
with prototypes so you do not write them by hand.

## API

```sh
klin --emit-h foo.kl              # → out/foo.h
klin --emit-c --emit-h foo.kl     # → out/foo.c + out/foo.h
```

- only functions with `@[cexport]` (name = `codename`)
- Klin types → C as in `.c` emission (`stdint.h`, etc.)
- `#line` on prototypes; include guard `KLIN_<BASE>_H`
- does not replace pack `.a` / `.so`

Example: [`examples/cexport_add/`](../examples/cexport_add/).
Note: [`docs/09-ffi-c.md`](../docs/09-ffi-c.md), CLI: [`docs/06-cli.md`](../docs/06-cli.md).

## Out of scope

- automatic `.a` / `.so`
- `cexport` on methods / types (still out of scope for 045)
