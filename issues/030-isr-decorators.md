# 030 — Przerwania przez dekoratory (ergonomia ISR)

**Status:** 💭 do rozważenia
**Zależy od:** 010; mile widziane 011/027 (nazwy z SVD), 028 (`FromISR`)

## Pytanie

Czy da się **zgrabnie** obsługiwać IRQ/ISR atrybutami, ponad dzisiejsze
`@[codename("SysTick_Handler")]` z [010](010-bare-metal.md).

## Stan dziś

Nazwa symbolu musi zgadzać się z wektorem (startup `.s`); `codename` to już
minimalny dekorator.

## Rozważania / przykłady myślowe (nie speć)

- `@[isr]` / `@[interrupt("SysTick")]` / `@[irq(IRQ_TIM2)]` → automatyczny
  `codename` + konwencja z wektora/SVD
- powiązanie z 011/027: nazwy IRQ z SVD / tablicy wektorów
- reguły jak w C: krótki ISR, `volatile`, FreeRTOS `FromISR` — Klin **nie**
  ukrywa kontekstu przerwania
- opcjonalnie: ostrzeżenie checkera przy alokacji / długiej pracy w ISR

## Czego nie robić

Generowanie całej tablicy wektorów w Klinie (startup zostaje `.s` — 010);
ukryte prologi/epilogi inne niż C/ABI.
