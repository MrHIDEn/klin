# Klin library search paths (issue 020)

`import mathx` resolves `lib/mathx.kl` next to this entry — no flags needed:

```sh
cd examples/klin_lib
dart run ../../bin/klin.dart run app.kl
# → 5
```

Same module from an external directory:

```sh
# from repo root
dart run bin/klin.dart run -I examples/klin_lib/lib examples/klin_lib/app.kl
# or:
KLIN_PATH=examples/klin_lib/lib dart run bin/klin.dart run examples/klin_lib/app.kl
```

(When `lib/mathx.kl` exists beside `app.kl`, sibling/`lib/` win over `-I` /
`$KLIN_PATH`.) Details: [docs/11-biblioteki-klin.md](../../docs/11-biblioteki-klin.md).
