# 074 — `board` w `klin.mod` + wąski CubeMX `.ioc` (pinout)

**Status:** 💭 do rozważenia (po MVP [053](053-device-board-assets.md))
**Zależy od:** [053](053-device-board-assets.md) (`$device` + `device` w modzie + cache `asset/`); mile [054](054-embedded-project-layout.md); **nie** [031](031-biblioteki-hal.md)

## Kontekst

[053](053-device-board-assets.md) = chip / SVD (`device` + `$device`).  
Ten issue = **płytka / pinout**, w tym przyszły odczyt CubeMX **`.ioc`**.

Na razie **bez implementacji IOC**. Tu zapisujemy model, żeby nie zgubić decyzji:

- jeden plik **`klin.mod`** (nie osobny `klin.hw` / `klin.dev`)
- dyrektywa **`board`** (nie `hardware`, nie `device`)
- scope IOC = **tylko mapa pinów**, nie cały Cube

## Przykład `klin.mod`

```text
klin 1
require  github/mrhiden/osa v0.1.0
device   github/tinygo-org/stm32-svd/stm32f411.svd v0.1.0
board    github/mrhiden/boards/nucleo_f411re.ioc v0.1.0
```

| Dyrektywa | Artefakt | Kod |
|---|---|---|
| `require` | pakiet Klin (`.kl`) | `import` |
| `device` | chip SVD (`.svd`) — [053](053-device-board-assets.md) | `$device("…")` |
| `board` | płytka / pinout (`.ioc` lub później inny pack) | `$board("…")` |

Jawne (linia w modzie) i niejawne (`klin get …@ref` dopisuje `board`) — jak przy `require` / `device`.

## Składnia w źródle (później)

```klin
$device("github/tinygo-org/stm32-svd/stm32f411.svd", use: "RCC,GPIOA,STK")
$board("github/mrhiden/boards/nucleo_f411re.ioc")

fn main() {
  // stałe wygenerowane z IOC — tylko piny, np. LED → PA5
  GPIOA.MODER.MODER5.write(.Output)
}
```

- rodzina `$` (D3); **nie** `import "*.ioc"`
- ten sam `klin get` / cache `asset/` / `klin.lock` co SVD; **inny** parser po fetchu

## Kiedy otwierać implementację

1. MVP 053 działa (`device` + `$device` + offline offline).
2. Ręczne pinouty w `board_…` / katalogu [054](054-embedded-project-layout.md) bolą.
3. Scope nadal: **pinout only**.

## Zakres (gdy wejdzie)

- [ ] dyrektywa `board` w parserze `klin.mod` + lock
- [ ] `$board("…")` lokalnie, potem remote path
- [ ] parser **wycinka** `.ioc` → stałe pinów (nazwa → port/pin)
- [ ] zero HAL / clock tree / generowanego `main` z Cube
- [ ] e2e: jedno Nucleo `.ioc` → kilka stałych; blink bez ręcznego pinoutu
- [ ] docs: „nie zastępuje Cube”

## Czego nie robić

- pełny CubeMX → projekt Klin
- mylenie z `device` (SVD) ani z `require` (lib `.kl`)
- cichy download przy `run`
- HAL przez IOC — [031](031-biblioteki-hal.md)

## Powiązane

- [053](053-device-board-assets.md) — `$device` / `device` (chip); IOC świadomie tu, nie w 053
- [049](049-remote-imports.md) / [065](065-project-lockfile.md) — get / lock
- [054](054-embedded-project-layout.md) — layout `board/` (startup/ld) osobno od moda
- [075](075-board-pack-init-host.md) — board pack / `klin init` (ld+startup); host bez tej magii
- [031](031-biblioteki-hal.md) — HAL osobno
