# Library search paths (`lib/` / `-I`)

Resolve `import mathx` from a sibling `lib/` directory or an explicit search path.

## What

`app.kl` imports `mathx`. With `lib/mathx.kl` next to the entry, no flags are
needed. The same module can also be found via `-I` or `$KLIN_PATH`.

## Why

Issue [020](../../issues/020-klin-libraries.md): Klin libraries are ordinary
`.kl` files on a search path — no package registry for local modules.

## How

```sh
cd examples/klin_lib
dart run ../../bin/klin.dart run app.kl
# → 5
```

From repo root (external `lib/`):

```sh
dart run bin/klin.dart run -I examples/klin_lib/lib examples/klin_lib/app.kl
# or:
KLIN_PATH=examples/klin_lib/lib dart run bin/klin.dart run examples/klin_lib/app.kl
```

When `lib/mathx.kl` exists beside `app.kl`, sibling/`lib/` win over `-I` /
`$KLIN_PATH`.

## Links

- [docs/11-klin-libraries.md](../../docs/11-klin-libraries.md)
- [issues/020](../../issues/020-klin-libraries.md)
- Directory package (many files, one module): [`../pkg_geom/`](../pkg_geom/)
