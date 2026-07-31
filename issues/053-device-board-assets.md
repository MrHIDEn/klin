# 053 — `$device` + Go-like fetch SVD (IOC / board)

**Status:** 💭 do rozważenia
**Zależy od:** [027](027-svd-ergonomic-api.md); infrastruktura cache/fetch wspólna z [049](049-remote-imports.md) (gdy będzie); paczki opcjonalnie [020](020-biblioteki-klin.md) / [047](047-directory-modules.md)

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

## Cel A — Go-style fetch SVD (priorytet UX)

Użytkownik (lub cienka paczka) pisze path jak moduł Go; Klin resolvuje →
cache → codegen. Bez ręcznego kopiowania `third_party/svd/`.

```klin
// top-level — nie w main
$device("github/tinygo-org/stm32-svd/stm32f411.svd", use: "RCC,GPIOA,STK")
// skrót katalogowy (opcjonalnie, później):
// $device("stm32f411", use: "RCC,GPIOA,STK")  // → znane mirror / allowlista

fn main() {
  RCC.AHB1ENR.GPIOAEN.set(1)
}
```

**Resolucja (jak `go mod` / [049](049-remote-imports.md)):**

1. lokalny plik / ścieżka względna (dziś)
2. cache użytkownika / projektu (po wcześniejszym fetch)
3. sieć: hosty z allowlisty (np. `tinygo-org/stm32-svd`, łatki stm32-rs —
   **nie** surowe ST jako domyślne; patrz [011](011-svd.md))
4. pin wersji / commit / tag w path albo lockfile — minimum przy realizacji

**Fetch widoczny:** osobne `klin get` / `klin update` z [049](049-remote-imports.md)
(ta sama infrastruktura cache co remote `import`; `update` odświeża też SVD
w cache). Ewentualnie pierwsza kompilacja loguje pobranie — bez cichej sieci.
`--offline` → błąd gdy brak cache.

Źródło domyślne: poprawione SVD ([tinygo-org/stm32-svd](https://github.com/tinygo-org/stm32-svd)),
nie surowe pliki ST.

## Cel B — warstwa paczek (opcjonalnie, równolegle)

Dla boardów / wielu peryferiów nadal sensowne cienkie paczki Klin:

```klin
import stm32_f411          // w środku: $device("github/…/stm32f411.svd", …)
import board_nucleo_f411re // stałe pinów; ewent. $board("…")
```

Aplikacja może więc:

- **bezpośrednio** `$device("github/…/….svd", …)` — jak Go, jeden plik, albo
- **`import` paczki** — gdy chcesz API boardu / gotowy zestaw `use:`.

Oba OK; remote SVD nie wymaga paczki pośredniej.

## Składnia built-inów

```klin
$device("…" /* lokalnie | github/…/name.svd | krótka nazwa */, use: "RCC,GPIOA")
$board("…")   // opcjonalnie, wąski .ioc → stałe; nie pełny CubeMX
```

- top-level, rodzina `$` (D3); dziś MVP = `$peripherals_from_svd`
- docelowo `$device` = nazwa kanoniczna (alias starego)
- **nie** `import "foo.svd"` w gramatyce `import` — to nadal moduły Klin;
  string remote dla SVD idzie przez `$device("…")` (ten sam *kształt* path
  co 049, inny keyword)

## Szkic ewolucji

1. **Teraz OK:** lokalne `$peripherals_from_svd` ([027](027-svd-ergonomic-api.md)).
2. **Potem:** `$device` + resolucja lokalna = jak dziś.
3. **Potem:** remote path `github/…/….svd` + cache + allowlista + widoczny fetch
   (współdzielić infrastrukturę z [049](049-remote-imports.md) gdzie się da).
4. **Opcjonalnie:** krótkie ID chipów (`stm32f411`); paczki board; `$board`.
5. **Później:** remote paczek Klin z `$device` w środku (049).

## Czego nie robić

- `import "x.svd"` jako składnia modułów — miesza z [048](048-import-aliases.md);
  fetch SVD = `$device("…")` (Go-like string, nie słowo `import`)
- osobne keyword `svd` / `ioc` / `device` poza rodziną `$`
- pełny CubeMX `.ioc` → Klin
- cichy download bez logu / bez możliwości `--offline`
- domyślnie surowe SVD ST (błędy — [011](011-svd.md)); mirror z łatkami
- HAL przez ten mechanizm — [031](031-biblioteki-hal.md)

## Kryterium (gdy wejdzie do prac)

- [ ] `$device("github/…/stm32f411.svd", …)` (lub równoważny path) → fetch + cache + codegen
- [ ] ponowna kompilacja offline z cache; `--offline` gdy brak pliku = błąd jasny
- [ ] allowlista hostów / znane mirror SVD; pin wersji (szkic)
- [ ] lokalna ścieżka nadal działa (regresja blink)
- [ ] zero-cost jak 027 (`objdump`)
- [ ] dokumentacja: `import` = Klin; `$device("github/…")` = artefakt jak Go-get
- [ ] (opcjonalnie) paczki `import stm32_…` / `$board` / krótkie ID chipa

## Powiązane

- [011](011-svd.md) / [027](027-svd-ergonomic-api.md) — generator i fluent API
- [023](023-examples.md) — `examples/stm32/`
- [054](054-embedded-project-layout.md) — układ katalogów / scaffold (osobno od SVD)
- [031](031-biblioteki-hal.md) — HAL osobno
- [048](048-import-aliases.md) / [049](049-remote-imports.md) — string/remote dla
  **modułów** Klin; ten issue = ten sam *styl* fetch dla **artefaktów** `$device`
