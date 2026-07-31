# 044 — Cykle CPU / SysTick → `Duration`

**Status:** 💭 do rozważenia
**Zależy od:** [010](010-bare-metal.md)

## Kontekst

Pomiary czasu w ns na hoście: `time.mono()`. Na MCU często DWT CYCCNT /
SysTick — to **nie** należy do module `time` jako ukryte `now()`.

## Propozycja

```klin
let c0 = cpu.cycles()
// …
let dt = cpu.cycles_since(c0, freq_hz)   // → time.Duration; freq_hz jawne
```

- osobny moduł (`cpu` / board); jawna częstotliwość — zero magii
- wynik kompatybilny z `time.Duration` (ns po przeliczeniu)

## Czego nie robić

- Wrzenia CYCCNT w `time.now()` / `time.mono()` bez osobnego API.
- Ukrytego `freq_hz` w globalnym stanie bez dokumentacji kosztu.
- RTC ([043](043-rtc.md)) w tym samym kroku.
