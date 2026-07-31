# 046 — Nagłówek C z eksportów (`--emit-h`)

**Status:** ✅ zrobione
**Zależy od:** [045](045-cexport.md)

## Kontekst

Po `@[cexport, codename]` C woła symbole Klin; `--emit-h` generuje nagłówek
z prototypami, żeby nie pisać ich ręcznie.

## API

```sh
klin --emit-h foo.kl              # → out/foo.h
klin --emit-c --emit-h foo.kl     # → out/foo.c + out/foo.h
```

- tylko funkcje z `@[cexport]` (nazwa = `codename`)
- typy Klina → C jak w emisji `.c` (`stdint.h` itd.)
- `#line` przy prototypach; include guard `KLIN_<BASE>_H`
- nie zastępuje pack `.a` / `.so`

Przykład: [`examples/cexport_add/`](../examples/cexport_add/).
Nota: [`note/09-ffi-c.md`](../note/09-ffi-c.md), CLI: [`note/06-cli.md`](../note/06-cli.md).

## Poza zakresem

- automatyczne `.a` / `.so`
- `cexport` na metodach / typach (nadal poza 045)
