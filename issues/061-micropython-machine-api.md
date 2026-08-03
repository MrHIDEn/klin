# 061 — MicroPython `machine`-style API (PWM, UART, …)

**Status:** ✅ decided (external package; not Klin stdlib)
**Depends on:** [010](010-bare-metal.md); nice to have [031](031-hal-libraries.md), [027](027-svd-ergonomic-api.md), [053](053-device-board-assets.md)
**Packages:** [`machine_stm32`](https://github.com/klin-lang/machine_stm32) (`Pin` + `Pwm` + `Rc` + `Uart` `@v0.4.0`), [`machine_rp`](https://github.com/klin-lang/machine_rp) (`Pin` + `Pwm` + `Rc` `@v0.5.0`), [`machine_esp`](https://github.com/klin-lang/machine_esp) (`Pin` + `Pwm` + `Rc` `@v0.3.0`), [`machine_xmega`](https://github.com/klin-lang/machine_xmega) (`Pin` `@v0.1.1`), [`machine_avr`](https://github.com/klin-lang/machine_avr) (`Pin` `@v0.1.0`), [`machine_pic16`](https://github.com/klin-lang/machine_pic16) (`Pin` `@v0.1.0`)

## Verdict

| Question | Answer |
|---|---|
| Change the Klin compiler? | **No** for the library itself |
| Where does the code live? | External repos (not `stdlib/`): **`machine_stm32`**, **`machine_rp`**, **`machine_esp`**, **`machine_xmega`**, **`machine_avr`**, **`machine_pic16`** |
| STM32? | **Yes** — [`machine_stm32`](https://github.com/klin-lang/machine_stm32) (`Pin` + `Pwm` + `Rc` + `Uart` `@v0.4.0`; F411/F401-class MMIO, no runtime chip detect) |
| RP2040 / RP2350? | **`machine_rp`** — Pin ✅; **Pwm** ✅; **Rc** ✅ `@v0.5.0` (`rc_out` / `rc_out_rp2350`); ([062](062-targets-esp-rp.md)) |
| ESP32-C3? | **`machine_esp`** — Pin ✅; **Pwm** ✅; **Rc** ✅ `@v0.3.0` (LEDC); blink/PWM/RC via **minimal ESP-IDF** boot; Wi‑Fi / freestanding later ([062](062-targets-esp-rp.md)) |
| ATxmega? | **`machine_xmega`** — Pin ✅ `@v0.1.1` (ATxmega128A1U-class PORT MMIO; formerly `machine_atmel`); Pwm later |
| megaAVR (Arduino Uno/Mega)? | **`machine_avr`** — Pin ✅ `@v0.1.0` (ATmega328P + ATmega2560 `DDRx`/`PORTx`/`PINx`); Pwm / tinyAVR later |
| PIC16? | **`machine_pic16`** — Pin ✅ `@v0.1.0` (PIC16F18855-class enhanced mid-range `LAT`/`PORT`/`TRIS`/`ANSEL`); PIC18/24/32 separate |
| Other PIC? | Separate ports if/when needed — not one library for all MCUs |
| Approach | **C** (thin Klin package over explicit MMIO) — not A, not full vendor HAL as the API |

Chosen over A/B: MicroPython-like **shape** (`Pin`, later `Pwm` / `Uart`), with no GC, no hidden heap, no hidden clock magic. Clock / startup / linker stay in the app (board pack later: [074](074-board-ioc-klin-mod.md), [075](075-board-pack-init-host.md)).

### Import

Repo / module name uses underscore (valid Klin identifier), same pattern as `osa` / `eventloop`:

```klin
import "github/klin-lang/machine_stm32" machine

fn main() {
    let led = machine.pin_out(machine.Port.A, 5)
    led.toggle()
}
```

```sh
klin get github/klin-lang/machine_stm32@v0.4.0
```

### Pwm shape (shared convention, not one runtime)

Same *method names* across `machine_*` ports; **separate MMIO** per MCU
(no shared `machine` package, no `#ifdef` mega-driver):

| Piece | Role |
|---|---|
| `pwm_out(…)` | factory — chip-specific args OK |
| `freq(hz)` | frequency in Hz |
| `duty_u16(d)` | duty `0..=65535` (MicroPython-style) |
| `deinit()` | stop this PWM (explicit) |

### Rc shape (servo / RC pulse — ports that have Pwm)

| Piece | Role |
|---|---|
| `rc_out(…, freq_hz, us_min, us_max)` | factory — same HW args as `pwm_out` + frame/pulse range |
| `out(pos, k)` | `pos` `0..=100_000`, `k` trim µs (−1000..=1000), silent clamp |
| `out_f32(pos, k)` | `pos` `0.0..=1.0` (1.0 ≡ 100_000) |
| `pulse_us(us)` | raw pulse width |
| `deinit()` | stop underlying PWM |

Pin-only ports (`machine_avr` / `xmega` / `pic16`) have no `rc_out` until they get Pwm.

### Uart shape (shared convention)

| Piece | Role |
|---|---|
| `uart_out(…, usart_clk_hz, baud)` | factory — chip-specific instance/pins/AF OK |
| `write_u8(b)` / `write(buf)` | blocking TX (`[]u8`) |
| `read_u8()` | blocking RX (0..=255) |
| `try_read_u8()` | non-blocking RX (−1 if empty) |
| `any()` | RXNE / byte waiting |
| `deinit()` | disable USART (explicit) |

`machine_stm32` `@v0.4.0`:

```klin
// PA5 = TIM2_CH1 AF1; tim_clk_hz explicit (HSI 16 MHz at reset)
let led = machine.pwm_out(machine.Port.A, 5, 2, 1, 1, 16000000)
led.freq(1000)
led.duty_u16(32768)

let servo = machine.rc_out(machine.Port.A, 5, 2, 1, 1, 16000000, 50, 1000, 2000)
servo.out(50000, 0)
servo.out_f32(0.25, 0)

// Nucleo VCP: USART2 PA2/PA3 AF7
let u = machine.uart_out(
    2,
    machine.Port.A, 2, 7,
    machine.Port.A, 3, 7,
    16000000,
    115200
)
u.write_u8(65)
```

Examples: [`pwm_f411`](https://github.com/klin-lang/machine_stm32/tree/main/examples/pwm_f411),
[`rc_f411`](https://github.com/klin-lang/machine_stm32/tree/main/examples/rc_f411),
[`uart_f411`](https://github.com/klin-lang/machine_stm32/tree/main/examples/uart_f411),
[`machine_rp/examples/pwm_pico`](https://github.com/klin-lang/machine_rp/tree/main/examples/pwm_pico),
[`rc_pico`](https://github.com/klin-lang/machine_rp/tree/main/examples/rc_pico),
[`machine_esp/examples/pwm_c3`](https://github.com/klin-lang/machine_esp/tree/main/examples/pwm_c3),
[`rc_c3`](https://github.com/klin-lang/machine_esp/tree/main/examples/rc_c3).

`machine_rp` `@v0.5.0`:

```klin
// GPIO 25 → slice/channel from pin; sys_clk_hz explicit
let led = machine.pwm_out(25, 6000000)
led.freq(1000)
led.duty_u16(32768)
let servo = machine.rc_out(25, 6000000, 50, 1000, 2000)
// RP2350: machine.pwm_out_rp2350 / machine.rc_out_rp2350
```

`machine_esp` `@v0.3.0`:

```klin
// GPIO 8, LEDC ch 0, timer 0, APB 80 MHz
let led = machine.pwm_out(8, 0, 0, 80000000)
let servo = machine.rc_out(8, 0, 0, 80000000, 50, 1000, 2000)
```

### Roadmap

**`machine_stm32`**

1. **Pin** + blink (Nucleo-F411 PA5) — ✅  
2. **PWM** (TIM2–TIM5, explicit tim/ch/af/clk) — ✅ `@v0.2.0`  
3. **Rc** (servo / RC pulse on Pwm) — ✅ `@v0.3.0` (`rc_f411`)  
4. **Uart** (USART1/2/6, explicit clk/baud) — ✅ `@v0.4.0` (`uart_f411`)  
5. I2C / SPI / ADC when needed  

**`machine_rp`**

1. **Pin** + blink RP2040 (Pico GPIO 25) — ✅  
2. **Pin** + blink RP2350 Arm (Pico 2) — ✅ (`pin_out_rp2350`, `blink_pico2`)  
3. **Pin** + blink RP2350 RISC-V — ✅ (`blink_pico2_riscv`, same Pin API)  
4. **PWM** (`pwm_out` / `pwm_out_rp2350`) — ✅ `@v0.4.0`  
5. **Rc** (`rc_out` / `rc_out_rp2350`) — ✅ `@v0.5.0` (`rc_pico`)  
6. UART when needed  

**`machine_esp`**

1. **Pin** + blink ESP32-C3 (DevKitM-1 GPIO8) — ✅ (MMIO Pin; example boot via ESP-IDF)  
2. **PWM** (LEDC MMIO) — ✅ `@v0.2.0` (`pwm_c3`)  
3. **Rc** (LEDC) — ✅ `@v0.3.0` (`rc_c3`)  
4. Freestanding (no IDF) / other ESP chips / UART / Wi‑Fi — later  

**`machine_xmega`** (formerly `machine_atmel`)

1. **Pin** + blink ATxmega (XMEGA-A1U Xplained PORTR.0) — ✅ `@v0.1.1` (`blink_xmega`)  
2. **PWM** / **Rc** / UART — later  

**`machine_avr`**

1. **Pin** + blink ATmega328P (Arduino Uno D13 = PB5) — ✅ `@v0.1.0` (`blink_uno`)  
2. **Pin** + blink ATmega2560 (Arduino Mega D13 = PB7) — ✅ `@v0.1.0` (`blink_mega`, `pin_out_2560`)  
3. **PWM** / **Rc** / UART / tinyAVR — later  

**`machine_pic16`**

1. **Pin** + blink PIC16F18855 (Curiosity Nano RA0) — ✅ `@v0.1.0` (`blink_curiosity`)  
2. **PWM** / **Rc** / UART / classic F877A — later  

Other MCU families = other repos — not “one machine for everything”.

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

- Packages: https://github.com/klin-lang/machine_stm32 , https://github.com/klin-lang/machine_rp , https://github.com/klin-lang/machine_esp , https://github.com/klin-lang/machine_xmega , https://github.com/klin-lang/machine_avr , https://github.com/klin-lang/machine_pic16  





- MicroPython `machine`: https://docs.micropython.org/en/latest/library/machine.html  
- Klin vendor HAL: [031](031-hal-libraries.md)  
- Embedded project layout: [054](054-embedded-project-layout.md)  
- Other MCU targets: [062](062-targets-esp-rp.md)  
