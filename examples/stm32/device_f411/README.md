# Nucleo-F411RE blink — remote `$device`

Same LED blink as [`../blink_f411/`](../blink_f411/), but the SVD comes from
the Klin asset cache (not `third_party/svd/`).

## What

`klin.mod` pins a remote SVD; `blink.kl` uses
`$device("github/tinygo-org/stm32-svd/svd/stm32f411.svd", …)`. Makefile links
with `arm-none-eabi-gcc` like the local-SVD sibling.

## Why

Issue [053](../../../issues/053-device-board-assets.md): board examples can
`klin get` device assets instead of vendoring large SVD trees in-repo.

## How

```sh
cd examples/stm32/device_f411
# once — reads klin.mod, fills $KLIN_CACHE/asset/… + klin.lock
dart run ../../../bin/klin.dart get
make
# → blink.elf
```

`klin.mod`:

```
klin 1
device github/tinygo-org/stm32-svd/svd/stm32f411.svd main
```

## Links

- Local SVD sibling: [`../blink_f411/`](../blink_f411/)
- [docs/04-macros.md](../../../docs/04-macros.md)
- [issues/053](../../../issues/053-device-board-assets.md), [075](../../../issues/075-board-pack-init-host.md)
- Board index: [`../README.md`](../README.md)
