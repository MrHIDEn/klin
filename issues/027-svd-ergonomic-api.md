# 027 — Ładne API SVD (`$peripherals_from_svd` / fluent)

**Status:** ✅ zrobione
**Zależy od:** 011 (emitter / zero-cost MMIO) + 026 (preprocesor)

## Cel

Z [011](011-svd.md): `$peripherals_from_svd("…")` oraz składnia w stylu
`RCC.AHB1ENR.GPIOAEN.set(1)` / `.write(.Output)` / `.toggle()`.

Nie dublować parsera SVD — reuse `svd2klin` / wspólny `lib/svd`.

## MVP (zrobione)

- Built-in `$peripherals_from_svd("path.svd"[, "RCC,GPIOA,STK"])` w preprocesorze
  (`lib/svd/fluent.dart` + `lib/preprocess.dart`)
- Zapis `{stem}_regs.h` / `.kl` obok źródła + `@[cinclude(…)]`
- Rewrite fluent → istniejące `PERIPH_REG_FIELD_{set,write,toggle}`
  (dalej `static inline` w C → brak `bl` do accessorów)
- `.EnumName` jako jedyny argument → literał z SVD (`write(.Output)` → `write(1)`)
- Blink: [`examples/stm32/blink_f411/blink.kl`](../examples/stm32/blink_f411/blink.kl)

## Auto-gen przy kompilacji (później)

Jeśli źródło deklaruje chip/SVD, a wygenerowany artefakt nie istnieje albo
jest starszy niż SVD — `klin` sam odpala ten sam codegen co `svd2klin`
(in-process lib), potem parse/check/emit. Cache po mtime/hash; flaga
`--no-gen` gdy trzeba. Poza MVP — Makefile + ręczny `svd2klin` nadal OK;
`$peripherals_from_svd` już generuje przy preprocess.

## Kryterium

- [x] Blink na ładnej składni
- [x] objdump: brak `bl` do `RCC_*` / `GPIOA_*` / `STK_*` accessorów

## Potem

Czysty UX + Go-like fetch SVD (`$device("github/…/….svd")`, cache, paczki
board): [053](053-device-board-assets.md).
