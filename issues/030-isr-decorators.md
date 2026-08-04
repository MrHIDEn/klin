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

**Portable across MCUs** — not an STM32 feature. Any target with a startup /
CRT vector symbol works; only the **string** changes (must match that chip’s
linker name). Klin does not own IRQ numbering or the vector table.

```klin
@[isr("SysTick_Handler")]   // STM32 CMSIS example
fn systick_handler() {
    GPIOA.ODR.ODR5.toggle()
}

// Other chips: same attribute, different string from *their* startup, e.g.
// @[isr("USART_RX_vect")]          // megaAVR / avr-libc
// @[isr("TIMER1_COMPA_vect")]
```

How to wire it:

1. Copy the exact handler name from startup `.s` / vendor CRT / toolchain docs.
2. `@[isr("That_Exact_Name")]` on a void free `fn` with no parameters.
3. Link that startup (`@[link("…")]` or board Makefile).
4. Optional check: `nm` / `objdump` shows the symbol defined.

Example (STM32): [`examples/stm32/blink_f411/`](../examples/stm32/blink_f411/).
Docs: [docs/09-ffi-c.md](../docs/09-ffi-c.md) (ISR section + name table).

## Out of scope (MVP)

- Generating the vector table in Klin (startup stays `.s` — 010)
- Hidden prologues/epilogues other than C/ABI
- `@[irq(IRQ_TIM2)]` bare-ident args / SVD interrupt name lookup (011/027)
- FreeRTOS `FromISR` sugar beyond thin FFI (028 ✅ `@v0.3.0` + explicit yield)
- Checker warnings on allocation inside ISR

## History

Previously: only `@[codename("ExactVectorName")]`. MVP adds `isr` as
documented ISR intent + the same emission path.
