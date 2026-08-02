# 052 — `klinstruct`: pack/unpack buffers (pair to `@mrhiden/cstruct`)

**Status:** 💭 under consideration — MVP atoms in [klinstruct](https://github.com/MrHIDEn/klinstruct); richer declaration → [059](059-kstruct-macros.md)
**Depends on:** [007](007-pointers-arrays-slices.md); nice to have [020](020-klin-libraries.md) / [047](047-directory-modules.md); remote → [049](049-remote-imports.md); `$kstruct` declarations → [059](059-kstruct-macros.md)

## Context

[`@mrhiden/cstruct`](https://github.com/MrHIDEn/cstruct) (TS/JS) packs/unpacks
binary buffers (Buffer ⇔ object) per a type model (LE/BE, atoms, offsets).

Goal: separate **Klin** library — working name `klinstruct` / repo
`github/mrhiden/klinstruct` — **the same approach on the Klin side**, so
JS (cstruct) and Klin speak a common wire format.

This is **not** FFI to npm nor a TypeScript port to Klin. Two implementations,
one binary contract.

## Sketch (later)

- Klin package: field model → `make` / `read` on `u8[]` / pointer + length
- endian LE/BE like cstruct; layout compatibility (order, sizes, padding)
- cross tests: same buffer hex from cstruct and klinstruct
- optional `$…` macros for models → [059](059-kstruct-macros.md) (depends on [026](026-preprocessor.md))
- after [049](049-remote-imports.md): `import "github.com/mrhiden/klinstruct" kstruct`

## Out of scope

- runtime dependency on Node / `@mrhiden/cstruct`
- generating TS from Klin in MVP (separate decision / tool)
- priority relative to language core / embedded
