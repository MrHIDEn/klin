# 033 — Formatowanie w stylu Go (`gofmt`)

**Status:** 💭 do rozważenia
**Zależy od:** stabilna gramatyka (praktycznie po 005+); nie blokuje kolejki głównej

## Cel

Jeden kanoniczny styl źródła Klina — jak `gofmt` w Go: **mało opcji,
zawsze ten sam wynik**, żeby dało się formatować automatycznie bez dyskusji
o tabach, nawiasach i łamaniu linii.

## Motivacja

Dziś przykłady i expand makr (`$fn`, `--emit-pp`) mają niespójne wcięcia.
Bez oficjalnego formatera każdy plik wygląda inaczej; makra wklejają ciało
1:1 i „psują” wygląd po expandzie.

## Propozycja

- Narzędzie CLI: `klin fmt <plik.kl…>` (ew. `-w` zapis na miejscu, domyślnie stdout)
- Wejście: tekst → lex/parse (albo tokeny + drzewo) → pretty-print
- Reguły bliskie Go:
  - wcięcia tabulacją **albo** stałe 2/4 spacje — **jedna decyzja**, zero flag
  - spacje wokół operatorów, po przecinkach
  - klamry w stylu K&R / Go (`fn main() {` w tej samej linii)
  - puste linie między deklaracjami top-level; brak „ozdób” do konfiguracji
- Idempotencja: `fmt(fmt(x)) == fmt(x)`
- Integracja: opcjonalnie w CI / pre-commit; nie w pipeline emit C

## Poza MVP (na później)

- Formatowanie **ciał makr** / wyniku `--emit-pp` (dedent + `fmt`)
- LSP / editor `formatDocument`
- `klin fmt ./...` rekursywnie

## Kryterium

- [ ] `klin fmt` na `examples/*.kl` daje powtarzalny, czytelny wynik
- [ ] dokument stylu w `note/` (krótki: „robimy jak Go, bez opcji”)
- [ ] przynajmniej jeden golden: brzydki `.kl` → sformatowany `.kl`
