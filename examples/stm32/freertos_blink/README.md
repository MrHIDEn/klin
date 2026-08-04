# FreeRTOS blink — Nucleo-F411RE (issue 028)

Board-shaped demo: **`klin_freertos` + `machine_stm32`**, ≥2 tasks, LED on **PA5**.

| Piece | Role |
|---|---|
| `$rtos_task(blink, …)` | `pin_out(A, 5)` + `toggle` + `task_delay` |
| `$rtos_task(heartbeat, …)` | second runnable (`task_delay` only) |
| `startup.s` / `linker.ld` | same F411 pack as other STM32 examples |
| `freertos_stubs/` | emit-c / object compile without a kernel |

## Prerequisites

```sh
# from this directory
dart run ../../../bin/klin.dart get
```

Pins (`klin.mod`): `klin_freertos@v0.3.0`, `machine_stm32@v0.5.0`.

Toolchain for the default target: `arm-none-eabi-gcc`.

## Emit / compile check (stubs)

```sh
make KLIN=/path/to/klin/bin/klin.dart
# → out/blink.c out/blink.o
```

This does **not** link a scheduler. Stubs stand in for FreeRTOS headers only.

## Board ELF (real FreeRTOS)

1. Obtain FreeRTOS kernel + **GCC/ARM_CM4F** port (vendor pack or
   [FreeRTOS-Kernel](https://github.com/FreeRTOS/FreeRTOS-Kernel)).
2. Add a board `FreeRTOSConfig.h` (tick rate, heap, priorities) on the include
   path — replace or extend `-I freertos_stubs` with your config + kernel
   `include/`.
3. The FreeRTOS port must provide **SVC / PendSV / SysTick** (our `startup.s`
   only has weak defaults).
4. Link:

```sh
make elf FREERTOS_DIR=/path/to/FreeRTOS-Kernel KLIN=…
```

Adjust the `elf` recipe’s source list if your tree layout differs. Flash
`blink.elf` with your usual Nucleo tool (OpenOCD / probe-rs / STM32CubeProgrammer).

## Contract

- No hidden allocation in Klin: stacks/prios are explicit in `$rtos_task`.
- GPIO stays in `machine_stm32`; RTOS stays in `klin_freertos`.
- FromISR / idle wake: separate APIs (`klin_freertos` `@v0.3.0`) — not this demo.

## Links

- Issue: [028](../../../issues/028-freertos.md)
- Packages: [klin_freertos](https://github.com/klin-lang/klin_freertos),
  [machine_stm32](https://github.com/klin-lang/machine_stm32)
- Bare-metal Pin blink (no RTOS): [`../blink_f411/`](../blink_f411/),
  [machine_stm32 examples/blink_f411](https://github.com/klin-lang/machine_stm32/tree/main/examples/blink_f411)
