# 030 — Interrupts via decorators (ISR ergonomics)

**Status:** 💭 to consider
**Depends on:** 010; 011/027 welcome (names from SVD), 028 (`FromISR`)

## Question

Can we **elegantly** handle IRQ/ISR with attributes, beyond today's
`@[codename("SysTick_Handler")]` from [010](010-bare-metal.md).

## State today

Symbol name must match the vector (startup `.s`); `codename` is already
minimal decorator.

## Considerations / thought examples (not spec)

- `@[isr]` / `@[interrupt("SysTick")]` / `@[irq(IRQ_TIM2)]` → automatic
  `codename` + convention from vector/SVD
- tie to 011/027: IRQ names from SVD / vector table
- rules like C: short ISR, `volatile`, FreeRTOS `FromISR` — Klin **does not**
  hide interrupt context
- optionally: checker warning on allocation / long work in ISR

## What not to do

Generate entire vector table in Klin (startup stays `.s` — 010);
hidden prologues/epilogues other than C/ABI.
