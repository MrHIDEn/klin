# 022 — Biblioteki / jednostki ASM

**Status:** 💭 do rozważenia
**Zależy od:** 010 (bare metal) lub wcześniejsze potrzeby hosta; 006?

## Kontekst

Na bare-metalu startup, wektory przerwań i krytyczne fragmenty często
zostają w surowym `.s` obok kodu (już założone w architekturze — nie
opakowywać). Pytanie na później: jak Klin **wiąże** i **deklaruje**
symbole z ASM (i odwrotnie: jak ASM woła zmanglowane symbole Klin).

## Propozycja (później)

- dołączanie `.s` / `.S` do buildu (CLI / manifest), bez translacji przez Klin
- deklaracje zewnętrzne zgodne z manglingiem (`@[codename(...)]` z D4)
- dokumentacja konwencji wywołań / rejestrów per target

Nie generować ASM z Klina „dla wygody”, jeśli wystarczy link z plikiem
użytkownika.

## Czego nie robić teraz

- Nie pisać assemblera ani DSL-a ASM wewnątrz `.kl`.
- Nie blokować 010 na pełnym modelu bibliotek ASM — surowy `.s` obok
  wystarczy na LED.
