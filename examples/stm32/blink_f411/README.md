# Nucleo-F411RE blink — local SVD

Bare-metal LED blink on PA5 using a vendored SVD and `$peripherals_from_svd`.

## What

`blink.kl` toggles the Nucleo green LED. `svd2klin` generates register bindings
from `third_party/svd/stm32f411.svd`. `@[link("startup.s")]` feeds objects into
`out/blink.link` for the Makefile.

## Why

Baseline board demo without remote assets — contrast with
[`../device_f411/`](../device_f411/) (`$device` + `klin.mod` / cache).

## How

Requires `arm-none-eabi-gcc` and Dart.

```sh
cd examples/stm32/blink_f411
make
# → blink.elf
```

Optional C reference build: `make ref` → `blink_ref.elf`.

## Links

- Sibling (remote `$device`): [`../device_f411/`](../device_f411/)
- [docs/04-macros.md](../../../docs/04-macros.md)
- [issues/027](../../../issues/027-svd-ergonomic-api.md), [075](../../../issues/075-board-pack-init-host.md)
- Board index: [`../README.md`](../README.md)
