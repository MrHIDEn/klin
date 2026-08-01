# 054 — Wygląd / układ projektu embedded

**Status:** 💭 do rozważenia
**Zależy od:** [023](023-examples.md) (układ `examples/stm32/`), [010](010-bare-metal.md);
mile widziane [053](053-device-board-assets.md) (czysty `$device`), [022](022-biblioteki-asm.md);
inne rodziny MCU: [062](062-targets-esp-rp.md)

## Problem

Dziś [`examples/stm32/blink_f411/`](../examples/stm32/blink_f411/) w jednym katalogu
miesza:

- źródło Klin (`blink.kl`) z długą ścieżką do SVD
- boilerplate: `startup.s`, `linker.ld`, `Makefile`
- referencja C (`blink_ref.c`)
- generowane `*_regs.h` / `*_regs.kl`

Dla kogoś, kto otwiera „projekt Klin na Nucleo”, wygląda to jak kupka plików
toolchaina, nie jak mała aplikacja. [023](023-examples.md) ustaliło tylko
`stm32/<nazwa>/` — bez konwencji „app vs board vs vendor” ani scaffoldu.

[053](053-device-board-assets.md) poprawia UX **kodu** (SVD / fetch); ten issue
= UX **katalogów i szablonu projektu**.

## Cel

Czytelny układ freestanding, w którym:

1. aplikacja to głównie `main.kl` (lub mało plików Klin) + `import` / `$device`
2. linker / startup / wspólny Make siedzą w `board/` / `vendor/` / wspólnym
   targetcie — nie „krzyczą” w rootzie dema
3. ewent. `klin init` (lub skopiowalny szablon Nucleo-F411) generuje ten układ

Szkic (orientacyjny, nie speć):

```
blink_f411/
  main.kl              # albo blink.kl — mało szumu
  board/               # startup.s, linker.ld, pinout / stałe
  Makefile             # cienki; include wspólnych reguł freestanding
```

Albo wspólny `examples/stm32/_common/` + dema tylko z `main.kl` + krótkim Make.

Startup nadal może być surowym `.s` ([010](010-bare-metal.md)) — chodzi o
**gdzie leży**, nie o ukrycie w magii Klina.

## Szkic ewolucji

1. Ustalona konwencja katalogów + refaktor blinka (docs `examples/README.md`)
2. Wspólne reguły Make / skrypt pod ARM (bez zmiany semantyki języka)
3. Opcjonalnie: `klin init nucleo-f411` (lub szablon w repo) — po [053](053-device-board-assets.md)
   sensowniejsze (`$device` zamiast `../../../third_party/...`).
   Wnioski host vs MCU + **trzy warstwy** (pack / init / `board`+.ioc):
   [075 §1b](075-board-pack-init-host.md).

## Czego nie robić

- pełne IDE / plugin CubeMX / wizard graficzny
- opakowywanie tablicy wektorów w „magiczny” Klin ([010](010-bare-metal.md))
- zmiana semantyki `import` / FFI tylko po to, by schować pliki
- obiecywać HAL przez layout — to [031](031-biblioteki-hal.md)

## Kryterium (gdy wejdzie do prac)

- [ ] blink (lub nowy szablon) czytelny: app Klin osobno od linker/startup
- [ ] build ARM bez regresji (elf / `SysTick_Handler` jak dziś)
- [ ] `examples/README.md` opisuje konwencję
- [ ] (opcjonalnie) `klin init` albo skopiowalny szablon w repo

## Powiązane

- [010](010-bare-metal.md) / [023](023-examples.md) — bare metal + `examples/stm32/`
- [022](022-biblioteki-asm.md) — `@[link]` / `out/*.link`
- [053](053-device-board-assets.md) — czysty device / SVD
- [075](075-board-pack-init-host.md) — board pack / init vs host (linker & startup)
- [028](028-freertos.md) — kolejne dema też pod tą konwencją
