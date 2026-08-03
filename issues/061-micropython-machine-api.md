# 061 — MicroPython `machine`-style API (PWM, UART, …)

**Status:** ✅ decided (external package; not Klin stdlib)
**Depends on:** [010](010-bare-metal.md); nice to have [031](031-hal-libraries.md), [027](027-svd-ergonomic-api.md), [053](053-device-board-assets.md)
**Package:** https://github.com/MrHIDEn/machine-stm32

## Verdict

| Question | Answer |
|---|---|
| Change the Klin compiler? | **No** for the library itself |
| Where does the code live? | External repo **`MrHIDEn/machine-stm32`**, not `stdlib/` |
| STM32? | **Yes** — first port (MVP: `Pin` + blink) |
| RP2040 / Atmel / PIC? | Same Klin language; **separate ports** later ([062](062-targets-esp-rp.md)). Not one library for all MCUs |
| Approach | **C** (thin Klin package over explicit MMIO) — not A, not full vendor HAL as the API |

Chosen over A/B: MicroPython-like **shape** (`Pin`, later `Pwm` / `Uart`), with no GC, no hidden heap, no hidden clock magic. Clock / startup / linker stay in the app (board pack later: [074](074-board-ioc-klin-mod.md), [075](075-board-pack-init-host.md)).

### Import note (repo hyphen)

Klin remote imports require the last path segment to be a valid module identifier.
`machine-stm32` contains `-`, so `import "github/mrhiden/machine-stm32"` cannot match `module …` today.

**Use today:** relative / `KLIN_PATH` import of the `machine/` directory:

```klin
import "../../machine"   // from examples/… in that repo
// or: KLIN_PATH=<clone> → import machine
```

Optional later: rename the GitHub repo to `machine_stm32` (underscore) for `klin get` parity with `osa` / `eventloop`.

### Roadmap (in `machine-stm32`)

1. **Pin** + blink (Nucleo-F411 PA5) — ✅ in [`machine-stm32`](https://github.com/MrHIDEn/machine-stm32)  

2. PWM + UART on the same STM32  
3. I2C / SPI / ADC when needed  
4. Other chips = other repos / ports, not “one machine for everything”

## Context

[MicroPython](https://docs.micropython.org/en/latest/library/machine.html)
provides **ready-made peripheral classes** in the `machine` module — same API shape on
many ports (STM32, RP2, ESP, …). Programmer calls PWM/UART without manual
MMIO or CubeMX.

Klin today: SVD / registers ([011](011-svd.md) / [027](027-svd-ergonomic-api.md))
or vendor HAL via FFI ([031](031-hal-libraries.md)). No
“like `machine.PWM`” layer in stdlib.

This issue = **inspiration catalog + decision** whether Klin wants a thin, explicit
board/chip API (no hidden allocation / magic), not a MicroPython port.

## What MicroPython has in `machine` (off-the-shelf)

Source: `machine` documentation (ports differ in completeness).

### Peripheral classes (core)

| Class | Meaning |
|---|---|
| `Pin` | GPIO in/out/open-drain, pull, irq |
| `Signal` | Pin + inverted logic (active low) |
| `PWM` | frequency + duty (`duty_u16` / `duty_ns`) |
| `ADC` / `ADCBlock` | analog measurement |
| `DAC` | analog output (when MCU has it) |
| `UART` | serial duplex (baud, tx/rx, read/write) |
| `SPI` / `SoftSPI` | SPI (HW vs bit-bang) |
| `I2C` / `SoftI2C` / `I2CTarget` | I²C controller / target |
| `I2S` | audio bus |
| `CAN` | Controller Area Network |
| `Timer` | hardware timers / callbacks |
| `Counter` / `Encoder` | pulse counting / quadrature |
| `RTC` | real-time clock → also [043](043-rtc.md) |
| `WDT` | watchdog |
| `SD` / `SDCard` | SD card (port-specific) |
| `USBDevice` | USB device (newer ports) |

### “Board / CPU” functions (selected)

`reset`, `soft_reset`, `freq`, `idle`, `sleep` / `lightsleep` /
`deepsleep`, `disable_irq` / `enable_irq`, `time_pulse_us`, `bitstream`, …
(set depends on port).

### Outside `machine`, but “ready” on embedded

- `time` / `utime` — sleep, ticks  
- `network` — Wi‑Fi/Ethernet (ESP etc.)  
- `bluetooth`, `esp*`, `rp2`, `stm` — port-specific  
- `uos` / VFS — files on flash/SD  

For Klin most important initially: **Pin, PWM, UART, I2C, SPI, ADC,
Timer, WDT** (what people expect from “like MicroPython”).

## UX example (MicroPython)

```python
from machine import Pin, PWM, UART

led = Pin(2, Pin.OUT)
pwm = PWM(Pin(15), freq=1000, duty_u16=32768)
uart = UART(1, baudrate=115200, tx=Pin(4), rx=Pin(5))
uart.write(b"hi\n")
```

## What it means for Klin

| Approach | Meaning |
|---|---|
| **A. SVD + examples only** | status quo; zero “machine” |
| **B. FFI to vendor HAL/LL** | [031](031-hal-libraries.md) — C alongside, thin `@[cimport]` |
| **C. Thin Klin `machine` package (external)** | Pin/PWM/UART… as explicit API over MMIO; **no** GC, no hidden heap; init/clock still explicit (startup / board pack [053](053-device-board-assets.md)) — **chosen**; lives outside the compiler repo |

Preference aligned with overarching rule: if C, then **explicit** clock tuning
/ pin mux / errors; do not promise full portability like µPython
(different MCUs = different PWM/timer limits).

## Out of scope

- Interpreter / GC / dynamic types like µPython  
- Full parity of all ports and classes (`CAN`, `I2S`, `USBDevice` in MVP)  
- Hidden callbacks with allocation in IRQ  
- Priority relative to language core  
- Putting `machine` into Klin `stdlib/`

## Links

- Package: https://github.com/MrHIDEn/machine-stm32  
- MicroPython `machine`: https://docs.micropython.org/en/latest/library/machine.html  
- Klin vendor HAL: [031](031-hal-libraries.md)  
- Embedded project layout: [054](054-embedded-project-layout.md)  
- Other MCU targets: [062](062-targets-esp-rp.md)  
