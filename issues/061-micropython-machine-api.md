# 061 — API w stylu MicroPython `machine` (PWM, UART, …)

**Status:** 💭 do rozważenia (niski priorytet — nieblokujące)
**Zależy od:** [010](010-bare-metal.md); mile [031](031-biblioteki-hal.md), [027](027-svd-ergonomic-api.md), [053](053-device-board-assets.md)

## Kontekst

[MicroPython](https://docs.micropython.org/en/latest/library/machine.html)
daje w module `machine` **gotowe klasy peryferiów** — ten sam kształt API na
wielu portach (STM32, RP2, ESP, …). Programista woła PWM/UART bez ręcznego
MMIO ani Cubemx.

Klin dziś: SVD / rejestry ([011](011-svd.md) / [027](027-svd-ergonomic-api.md))
albo vendor HAL przez FFI ([031](031-biblioteki-hal.md)). Brak warstwy
„jak `machine.PWM`” w stdlib.

To issue = **katalog inspiracji + decyzja**, czy Klin chce cienką, jawną
warstwę board/chip API (bez ukrytej alokacji / magii), nie port MicroPythona.

## Co MicroPython ma w `machine` (gotowce)

Źródło: dokumentacja `machine` (porty różnią się kompletnością).

### Klasy peryferiów (rdzeń)

| Klasa | Sens |
|---|---|
| `Pin` | GPIO in/out/open-drain, pull, irq |
| `Signal` | Pin + logika odwrócona (aktywny niski) |
| `PWM` | częstotliwość + duty (`duty_u16` / `duty_ns`) |
| `ADC` / `ADCBlock` | pomiar analogowy |
| `DAC` | wyjście analogowe (gdy MCU ma) |
| `UART` | serial duplex (baud, tx/rx, read/write) |
| `SPI` / `SoftSPI` | SPI (HW vs bit-bang) |
| `I2C` / `SoftI2C` / `I2CTarget` | I²C controller / target |
| `I2S` | audio bus |
| `CAN` | Controller Area Network |
| `Timer` | hardwartowe timery / callbacki |
| `Counter` / `Encoder` | zliczanie impulsów / kwadratura |
| `RTC` | zegar czasu rzeczywistego → też [043](043-rtc.md) |
| `WDT` | watchdog |
| `SD` / `SDCard` | karta SD (port-specific) |
| `USBDevice` | USB device (nowsze porty) |

### Funkcje „płyta / CPU” (wybrane)

`reset`, `soft_reset`, `freq`, `idle`, `sleep` / `lightsleep` /
`deepsleep`, `disable_irq` / `enable_irq`, `time_pulse_us`, `bitstream`, …
(zestaw zależy od portu).

### Poza `machine`, ale „gotowe” na embedded

- `time` / `utime` — sleep, ticks  
- `network` — Wi‑Fi/Ethernet (ESP itd.)  
- `bluetooth`, `esp*`, `rp2`, `stm` — port-specific  
- `uos` / VFS — pliki na flash/SD  

Na potrzeby Klina najważniejsze na start: **Pin, PWM, UART, I2C, SPI, ADC,
Timer, WDT** (to, czego ludzie oczekują po „jak w MicroPythonie”).

## Przykład UX (MicroPython)

```python
from machine import Pin, PWM, UART

led = Pin(2, Pin.OUT)
pwm = PWM(Pin(15), freq=1000, duty_u16=32768)
uart = UART(1, baudrate=115200, tx=Pin(4), rx=Pin(5))
uart.write(b"hi\n")
```

## Co to znaczy dla Klina

| Podejście | Sens |
|---|---|
| **A. Tylko SVD + przykłady** | status quo; zero „machine” |
| **B. FFI do vendor HAL/LL** | [031](031-biblioteki-hal.md) — C obok, cienkie `@[cimport]` |
| **C. Cienki `stdlib` / pakiet `machine` Klin** | Pin/PWM/UART… jako jawne API nad MMIO albo HAL; **bez** GC, bez ukrytego heapa; init/clock nadal świadomy (startup / board pack [053](053-device-board-assets.md)) |

Preferencja zgodna z zasadą nadrzędną: jeśli C, to **jawne** strojenie
zegarów / pin mux / błędów; nie obiecywać pełnej przenośności jak µPython
(różne MCU = różne ograniczenia PWM/timerów).

## Szkic (później)

1. Wybrać MVP klas: `Pin`, `PWM`, `Uart` (nazewnictwo Klin).
2. Jedna płyta referencyjna (np. Nucleo-F411 / RP2040) + przykład blink/PWM/UART
   — cele poza STM32: [062](062-targets-esp-rp.md).
3. Decyzja implementacji: czysty MMIO (SVD) vs LL vs mieszanka.
4. Dokumentacja: „to nie jest port MicroPythona; podobny kształt API”.

## Poza zakresem

- Interpreter / GC / dynamiczne typy jak w µPython  
- Pełny parity wszystkich portów i klas (`CAN`, `I2S`, `USBDevice` w MVP)  
- Ukryte callbacki z alokacją w IRQ  
- Priorytet względem rdzenia języka  

## Linki

- MicroPython `machine`: https://docs.micropython.org/en/latest/library/machine.html  
- Klin HAL vendora: [031](031-biblioteki-hal.md)  
- Layout projektu embedded: [054](054-embedded-project-layout.md)  
