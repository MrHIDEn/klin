# 027 — Ładne API SVD (`$peripherals_from_svd` / fluent)

**Status:** 💭 do rozważenia
**Zależy od:** 011 (emitter / zero-cost MMIO) + 026 (preprocesor)

## Cel

Z [011](011-svd.md): `$peripherals_from_svd("…")` oraz składnia w stylu
`RCC.AHB1ENR.GPIOAEN.set(1)` / `.write(.Output)` / `.toggle()`.

Nie dublować parsera SVD — reuse `svd2klin` / wspólny `lib/svd`.

## Auto-gen przy kompilacji (później)

Jeśli źródło deklaruje chip/SVD, a wygenerowany artefakt nie istnieje albo
jest starszy niż SVD — `klin` sam odpala ten sam codegen co `svd2klin`
(in-process lib), potem parse/check/emit. Cache po mtime/hash; flaga
`--no-gen` gdy trzeba. Poza MVP 011 — najpierw ręczny CLI + Makefile.

## Kryterium

Blink na ładnej składni; objdump jak ręczny C (bez `bl` do accessorów).
Wygoda nie ukrywa kosztu: bezpośredni RMW / dostęp do rejestru.
