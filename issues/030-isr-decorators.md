# 030 — Interrupts via decorators (ISR ergonomics)

**Status:** ✅ done (MVP)
**Depends on:** 010; 011/027 welcome later (names from SVD), 028 (`FromISR`)

## Question

Can we **elegantly** handle IRQ/ISR with attributes, beyond today's
`@[codename("SysTick_Handler")]` from [010](010-bare-metal.md).

## Verdict (MVP)

| Form | Meaning |
|---|---|
| `@[isr("SysTick_Handler")]` | preferred — vector C symbol; implies `codename` |
| `@[isr, codename("TIM2_IRQHandler")]` | same, explicit `codename` |

Checker rules (frontend; gcc never sees a bad shape):

- free `fn` with body (not `cimport` / `cexport` / `async` / `main`)
- no parameters; return `void` or omit return type
- symbol must match startup `.s` vector (same contract as bare `codename`)

Emission: **unchanged** — global C symbol via `codename` (no hidden prologue,
no vector-table generation). Bare `@[codename("…")]` still works (010 / 045).

```klin
@[isr("SysTick_Handler")]
fn systick_handler() {
    GPIOA.ODR.ODR5.toggle()
}
```

Example: [`examples/stm32/blink_f411/`](../examples/stm32/blink_f411/).

## Out of scope (MVP)

- Generating the vector table in Klin (startup stays `.s` — 010)
- Hidden prologues/epilogues other than C/ABI
- `@[irq(IRQ_TIM2)]` bare-ident args / SVD interrupt name lookup (011/027)
- FreeRTOS `FromISR` sugar (028)
- Checker warnings on allocation inside ISR

## History

Previously: only `@[codename("ExactVectorName")]`. MVP adds `isr` as
documented ISR intent + the same emission path.
