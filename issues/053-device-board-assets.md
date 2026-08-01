# 053 — `$device` + Go-like fetch SVD (IOC / board)

**Status:** ✅ MVP (SVD + `device` w `klin.mod`); board / `.ioc` → [074](074-board-ioc-klin-mod.md)  
**Zależy od:** [027](027-svd-ergonomic-api.md); [049](049-remote-imports.md)

## Kontekst

Dziś aplikacja (np. blink) woła wprost:

```klin
$peripherals_from_svd("../../../third_party/svd/stm32f411.svd", "RCC,GPIOA,STK")
```

To działa i jest zero-cost, ale UX miesza **lokalną ścieżkę do XML** z kodem
i wymaga ręcznego vendorowania SVD. Chcemy czystszego modelu: jak w Go —
**podajesz identyfikator / path artefaktu, Klin ściąga i cache’uje**.

`import` = moduły Klin (symbole, `pub`, mangling) — [048](048-import-aliases.md) /
[049](049-remote-imports.md).  
`$device` / `$board` = **artefakty vendora** (SVD, ewent. IOC) → codegen —
ten sam styl stringów co Go/`import "…"`, ale **inna komenda**, żeby nie
mieszać modeli.

## Cel A — Go-style fetch SVD (priorytet UX) — MVP ✅

Użytkownik (lub cienka paczka) pisze path jak moduł Go; Klin resolvuje →
cache → codegen. Bez ręcznego kopiowania `third_party/svd/`.

```klin
// top-level — nie w main
$device("github/tinygo-org/stm32-svd/svd/stm32f411.svd", "RCC,GPIOA,STK")
// alias: $peripherals_from_svd(…)

fn main() {
  RCC.AHB1ENR.GPIOAEN.set(1)
}
```

**Resolucja:**

1. lokalny plik / ścieżka względna (027)
2. cache `$KLIN_CACHE/asset/host/owner/repo/…` (po `klin get`)
3. sieć tylko przez `klin get` / `klin update` — allowlista
   `github/tinygo-org/stm32-svd` (nie surowe ST; patrz [011](011-svd.md))
4. pin w `klin.mod` (`device path ref`) + `klin.lock` (commit + sha256 pliku)

**Manifest — jeden `klin.mod`:**

```
klin 1
require github/mrhiden/osa v0.1.0
device github/tinygo-org/stm32-svd/svd/stm32f411.svd main
```

`klin get github/tinygo-org/stm32-svd/svd/stm32f411.svd@main` dopisuje `device`.
Bez args odświeża `require` **i** `device`. Kompilacja / `run` bez sieci;
brak cache → błąd z hintem `klin get`.

## Cel B — warstwa paczek (opcjonalnie, później)

```klin
import stm32_f411          // w środku: $device("github/…/….svd", …)
import board_nucleo_f411re // stałe pinów; ewent. $board("…")
```

## Składnia built-inów

```klin
$device("…" /* lokalnie | github/…/….svd */, "RCC,GPIOA")
$board("…")   // później — wąski .ioc → stałe; nie pełny CubeMX
```

- top-level, rodzina `$` (D3); `$device` = alias `$peripherals_from_svd`
- **nie** `import "foo.svd"` — string remote dla SVD idzie przez `$device("…")`

## Szkic ewolucji

1. ~~Lokalne `$peripherals_from_svd` ([027](027-svd-ergonomic-api.md)).~~
2. ~~`$device` + resolucja lokalna.~~
3. ~~Remote path + cache + allowlista + widoczny fetch + `device` w mod.~~
4. **Później:** `board` / wąski `.ioc` → [074](074-board-ioc-klin-mod.md); krótkie ID chipów; paczki board.
5. Remote paczek Klin z `$device` w środku (049).

## Czego nie robić

- `import "x.svd"` jako składnia modułów — miesza z [048](048-import-aliases.md);
  fetch SVD = `$device("…")` (Go-like string, nie słowo `import`)
- osobne keyword `svd` / `ioc` / `device` poza rodziną `$` (linia `device` w
  **modzie** jest OK — to nie keyword języka)
- pełny CubeMX `.ioc` → Klin — pinout / `$board` / dyrektywa `board` → [074](074-board-ioc-klin-mod.md)
- cichy download przy `run` / kompilacji
- domyślnie surowe SVD ST (błędy — [011](011-svd.md)); mirror z łatkami
- HAL przez ten mechanizm — [031](031-biblioteki-hal.md)

## Kryterium

- [x] `$device("github/…/….svd", …)` → `klin get` + cache + codegen
- [x] ponowna kompilacja offline z cache; brak pliku = błąd z `klin get`
- [x] allowlista (`github/tinygo-org/stm32-svd`); pin w mod + lock
- [x] lokalna ścieżka nadal działa (`$device` / `$peripherals_from_svd`)
- [x] zero-cost jak 027 (ten sam emitter)
- [x] dokumentacja: `import` = Klin; `$device("github/…")` = artefakt
- [x] przykład: [`examples/stm32/device_f411/`](../examples/stm32/device_f411/)
- [x] dyrektywa `device` w `klin.mod` (obok `require`; jawne + niejawne jak 049)
- [ ] (opcjonalnie) paczki `import stm32_…` / krótkie ID chipa — board → [074](074-board-ioc-klin-mod.md)

## Powiązane

- [011](011-svd.md) / [027](027-svd-ergonomic-api.md) — generator i fluent API
- [023](023-examples.md) — `examples/stm32/`
- [054](054-embedded-project-layout.md) — układ katalogów / scaffold (osobno od SVD)
- [031](031-biblioteki-hal.md) — HAL osobno
- [048](048-import-aliases.md) / [049](049-remote-imports.md) — string/remote dla
  **modułów** Klin; ten issue = ten sam *styl* fetch dla **artefaktów** `$device`
- [074](074-board-ioc-klin-mod.md) — `board` w `klin.mod` + wąski `.ioc` (po 053)
