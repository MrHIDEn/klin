# 044 — CPU cycles / SysTick → `Duration`

**Status:** 💭 under consideration
**Depends on:** [010](010-bare-metal.md)

## Context

Time measurements in ns on the host: `time.mono()`. On MCU, often DWT CYCCNT /
SysTick — this **does not** belong in the `time` module as a hidden `now()`.

## Proposal

```klin
let c0 = cpu.cycles()
// …
let dt = cpu.cycles_since(c0, freq_hz)   // → time.Duration; freq_hz explicit
```

- separate module (`cpu` / board); explicit frequency — zero magic
- result compatible with `time.Duration` (ns after conversion)

## What not to do

- Baking CYCCNT into `time.now()` / `time.mono()` without a separate API.
- Hidden `freq_hz` in global state without documenting the cost.
- RTC ([043](043-rtc.md)) in the same step.
