# 075 — Board pack / `klin init` vs host (laptop): linker & startup

**Status:** 💭 wnioski (docs); implementacja później  
**Zależy od:** [010](010-bare-metal.md), [054](054-embedded-project-layout.md), [053](053-device-board-assets.md); mile [074](074-board-ioc-klin-mod.md)

## Werdykt w skrócie

**Laptop (host): bez magii — bez `linker.ld`, `startup.s`, zwykle też bez Makefile.**

`klin run examples/hello.kl` wystarczy: Klin emituje C, woła host `gcc`/`clang`/`tcc`,
linkuje z **CRT + libc**. Nie trzeba `linker.ld`, `startup.s` ani `make`.
Makefile / ld / startup to świat **bare-metalu** (`examples/stm32/…`).

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

### 1b. Trzy warstwy ulgi na MCU (jak to ma wyglądać)

Nie jedna magia — **trzy osobne rzeczy**. GitHub pasuje do warstw A i C
(fetch jak `require` / `device`); B to jednorazowy scaffold lokalny.

#### A — Paczka boardu (ld + startup) — z GitHub

Repo / asset np. `github/…/board-nucleo-f411re` zawiera gotowe:

- `startup.s`, `linker.ld`, cienki Makefile / reguły,
- ewent. proste stałe pinów w `.kl`.

User: `klin get` (albo `require` paczki Klin) → pliki w cache / projekcie.
**Nie pisze** ld/startup sam. Build ARM nadal jawny (Make + `arm-none-eabi`),
tylko boilerplate jest **skopiowany / z packa**, nie wymyślony przez kompilator.

#### B — `klin init nucleo-f411` — scaffold (nie ciągły fetch)

Jednorazowo tworzy katalog projektu:

```text
my_blink/
  main.kl
  board/          # startup.s, linker.ld (z szablonu / packa A)
  Makefile
  klin.mod        # device … (+ ewent. require board pack)
  README          # „najpierw klin get”
```

Źródło szablonu może być **z tego samego GitHub packa (A)** albo z szablonów
w dystrybucji Klina. Potem pracujesz lokalnie; `get` tylko pinuje wersje —
init **nie** linkuje magicznie przy każdym buildzie.

#### C — `board` w `klin.mod` + `$board` — pinout z `.ioc` ([074](074-board-ioc-klin-mod.md))

Później, osobno od ld/startup:

```text
klin.mod:
  device github/…/stm32f411.svd main
  board  github/…/nucleo_f411re.ioc v0.1.0   # fetch jak device → asset/
```

```klin
$device("github/…/stm32f411.svd", "RCC,GPIOA,STK")  // MMIO z SVD
$board("github/…/nucleo_f411re.ioc")                 // stałe LED→PA5 itd.
```

- `klin get` ściąga `.ioc` do cache `asset/` (ziarno); typowy flow potem
  **kopiuje** do `board/*.ioc` w projekcie — lokalny plik = prawda, w gicie,
  **nie** nadpisywany przez `get`/`update` (szczegóły: [074](074-board-ioc-klin-mod.md)),
- parser wycina **tylko mapę pinów** → codegen stałych,
- **nie** generuje `linker.ld` / `startup.s` — te nadal z A (pack) / B (init).

| Warstwa | Skąd | Co daje userowi |
|---|---|---|
| A pack | GitHub (paczka / asset) | `startup.s` + `linker.ld` (+ Make) |
| B init | szablon (często z A) | katalog „od razu da się zbudować” |
| C `board`/`.ioc` | GitHub (asset, jak SVD) | nazwy pinów — **nie** linkowanie |

**Kolejność prac:** najpierw A+B (blink bez bólu ld), potem C (wygodniejszy
pinout z Cube). Host (laptop) w ogóle poza tym modelem — patrz §3.

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
- **Brak** Makefile — buduje i odpala **`klin run`** (ewent. `klin test`).
- **Brak** freestanding wektorów przerwań.

(Wyjątki hostowe z własnym Make — np. `ffi_add/` / `asm_add/` pod lib C —
to FFI, nie wymóg zwykłego programu.)

To nie jest „ten sam problem co Nucleo”. Host ≠ MCU; nie projektować UX
bare-metalu tak, jakby każdy program Klin wymagał ld/startup/Make.

| | Host | Bare-metal (STM32, …) |
|---|---|---|
| Budowa | `klin run` / `klin test` | Makefile (+ `arm-none-eabi-gcc`) |
| Entry / CRT | OS + toolchain | `startup.s` (wektory, Reset_Handler) |
| Skrypt linkera | domyślny hosta | `linker.ld` (`-T`, FLASH/RAM) |
| User pisze | `.kl` (+ ewent. `@[link]` do `.s`/`.a` FFI) | `.kl` + pack boardu (lub ręczny boilerplate) |
| `klin init`? | opcjonalnie lekki szablon app (`hello` + `klin.mod`) | **`klin init nucleo-f411`** (itp.) z `board/` + Make |

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
      — laptop: bez magii, bez `linker.ld`/`startup.s`/Makefile (`klin run`)
- [ ] co najmniej jeden board pack / szablon Nucleo-F411 bez edycji ld przez usera
- [ ] (opcjonalnie) `klin init nucleo-f411` albo równoważny scaffold w repo
- [ ] (opcjonalnie, niski priorytet) `klin init` host → `hello` + moda

## Powiązane

- [010](010-bare-metal.md) — startup zostaje `.s`; bez magii w języku
- [022](022-biblioteki-asm.md) — `@[link]`; `-T linker.ld` zostaje w Make
- [053](053-device-board-assets.md) — SVD / `$device` ≠ ld
- [054](054-embedded-project-layout.md) — układ `board/` + szkic init
- [074](074-board-ioc-klin-mod.md) — pinout / `.ioc`, nie linker
