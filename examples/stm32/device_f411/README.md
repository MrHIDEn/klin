# Nucleo-F411RE blink — remote `$device` (053)

Same LED blink as [`../blink_f411/`](../blink_f411/), but SVD comes from the
Klin asset cache (not `third_party/svd/`).

```sh
cd examples/stm32/device_f411
# once — reads klin.mod, fills $KLIN_CACHE/asset/… + klin.lock
dart run ../../../bin/klin.dart get
# emit C (offline) then link with arm-none-eabi-gcc
make
```

`klin.mod`:

```
klin 1
device github/tinygo-org/stm32-svd/svd/stm32f411.svd main
```

`blink.kl` uses `$device("github/tinygo-org/stm32-svd/svd/stm32f411.svd", …)`.
Lokalny vendor: [`../blink_f411/`](../blink_f411/) (`$peripherals_from_svd` +
`third_party/svd`). Docs: [note/04-makra.md](../../../note/04-makra.md),
[issues/053](../../../issues/053-device-board-assets.md).
