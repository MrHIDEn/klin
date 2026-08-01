# 075 — Board pack / `klin init` vs host (laptop): linker & startup

**Status:** 💭 wnioski (docs); implementacja później  
**Zależy od:** [010](010-bare-metal.md), [054](054-embedded-project-layout.md), [053](053-device-board-assets.md); mile [074](074-board-ioc-klin-mod.md)

## Werdykt w skrócie

**Laptop (host): bez magii linkera/startupu — bez tych plików.**

`klin run examples/hello.kl` nie wymaga `linker.ld` ani `startup.s`. Entry i
link robi **CRT + libc hosta** (gcc/clang/tcc). Żadnego freestanding, żadnej
tablicy wektorów. Magia ld/startup dotyczy **tylko bare-metalu** (`examples/stm32/…`).

## Problem

`linker.ld` + `startup.s` to największy próg wejścia bare-metalu: mapa pamięci,
tablica wektorów, kopiowanie `.data`, zerowanie `.bss`. User blinka nie powinien
musieć tego *rozumieć ani pisać* — ale Klin **nie chowa** tego w magii języka
(zasada: brak ukrytego kosztu; [010](010-bare-metal.md)).

SVD / `$device` ([053](053-device-board-assets.md)) **nie generuje** `.ld` ani
startupu — tylko MMIO / rejestry. Inna warstwa.

## Wnioski (werdykt)

### 1. Ulga = pack + scaffold, nie kompilator

| Podejście | Werdykt |
|---|---|
| Generować `linker.ld` z SVD | ❌ nie — SVD ≠ pełna mapa linkera; debug w czarną skrzynkę |
| Ukryć startup w „magicznym” Klinie | ❌ nie — [010](010-bare-metal.md) |
| Gotowy **board pack** (`startup.s` + `linker.ld` + ewent. pinout) | ✅ |
| **`klin init <board>`** (lub szablon w repo) kopiujący pack | ✅ — [054](054-embedded-project-layout.md) |
| Dyrektywa `board` / wąski `.ioc` (pinout) | później — [074](074-board-ioc-klin-mod.md); **nie** zastępuje ld/startup |

Cel UX: 95% userów **nigdy nie edytuje** `linker.ld` / `startup.s`; edytuje
`main.kl` + `$device` + ewent. pinout.

### 2. `linker.ld` jest inny per MCU (czasem board)

- **Chip** — FLASH/RAM size i origin, czasem regiony (CCM, ITCM, …)
- **Board** — rzadziej (zewnętrzny flash, offset aplikacji vs bootloader)
- **Aplikacja** — rzadko (dual-bank, własny layout)

To boilerplate **targetu / boardu**, nie linia w `klin.mod` obok `device`
(mod pinuje artefakty do fetch; ld leży w packu / `board/`).

### 3. Host (laptop) — **nie ma** tej magii i **nie ma tych plików**

Na laptopie ścieżka to `klin run` → emit C → host `gcc`/`clang`/`tcc` →
link z **systemowym CRT + libc** (crt0, domyślny skrypt linkera OS).

- **Brak** `startup.s` w projekcie hostowym.
- **Brak** `linker.ld` / `-T …` w typowym `klin run`.
- **Brak** freestanding wektorów przerwań.

To nie jest „ten sam problem co Nucleo”. Host ≠ MCU; nie projektować UX
bare-metalu tak, jakby każdy program Klin wymagał ld/startup.

| | Host | Bare-metal (STM32, …) |
|---|---|---|
| Entry / CRT | OS + toolchain | `startup.s` (wektory, Reset_Handler) |
| Skrypt linkera | domyślny hosta | `linker.ld` (`-T`, FLASH/RAM) |
| User pisze | `.kl` (+ ewent. `@[link]` do `.s`/`.a` FFI) | `.kl` + pack boardu (lub ręczny boilerplate) |
| `klin init`? | opcjonalnie lekki szablon app (`hello` + `klin.mod`) | **`klin init nucleo-f411`** (itp.) z `board/` |

### 4. Dwa sensy `klin init` (nie mylić)

1. **`klin init` (host)** — cienki projekt: `main.kl`, ewent. pusty/przykładowy
   `klin.mod`, bez ld/startup. Nice-to-have; dziś wystarczy skopiować
   `examples/hello.kl`.
2. **`klin init <board>` (MCU)** — właściwa ulga na ból linkera/startupu:
   katalog z `main.kl`, `board/{startup.s,linker.ld}`, cienki Makefile,
   `klin.mod` z `device …`, README „najpierw `klin get`”. To potomek /
   uszczegółowienie [054](054-embedded-project-layout.md).

Implementacja MCU-init **po** ustaleniu layoutu w 054; host-init osobno i
niższy priorytet.

## Czego nie robić

- obiecywać „Klin sam napisze linker z chipa”
- mieszać host CRT z freestanding w jednym „magicznym” trybie bez jawnego targetu
- pełny CubeMX → projekt ([074](074-board-ioc-klin-mod.md))
- HAL przez pack — [031](031-biblioteki-hal.md)

## Kryterium (gdy wejdzie implementacja)

- [x] udokumentowany podział: host vs MCU (ten issue + `examples/README`)
      — laptop: bez magii, bez `linker.ld`/`startup.s`
- [ ] co najmniej jeden board pack / szablon Nucleo-F411 bez edycji ld przez usera
- [ ] (opcjonalnie) `klin init nucleo-f411` albo równoważny scaffold w repo
- [ ] (opcjonalnie, niski priorytet) `klin init` host → `hello` + moda

## Powiązane

- [010](010-bare-metal.md) — startup zostaje `.s`; bez magii w języku
- [022](022-biblioteki-asm.md) — `@[link]`; `-T linker.ld` zostaje w Make
- [053](053-device-board-assets.md) — SVD / `$device` ≠ ld
- [054](054-embedded-project-layout.md) — układ `board/` + szkic init
- [074](074-board-ioc-klin-mod.md) — pinout / `.ioc`, nie linker
