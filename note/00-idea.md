# Klin — ogólna idea

## Czym jest

Klin to język systemowy kompilowany **do C**, a nie do kodu maszynowego.
Kompilator Klina generuje jeden czytelny plik `.c`, który następnie
obsługuje zwykły kompilator C (gcc, clang, tcc, arm-none-eabi-gcc).

Nazwa nie jest przypadkowa: klin to najstarsza maszyna prosta — zero
ruchomych części, zero narzutu. Język jest cienką warstwą **wklinowaną**
między programistę a C. Nie zastępuje C, nie ukrywa go, nie udaje, że go nie ma.

## Zasada nadrzędna

> **Żadnej ukrytej alokacji, żadnego ukrytego przepływu sterowania,
> żadnego ukrytego kosztu. Jeśli coś alokuje albo skacze, musi to być
> widoczne w składni.**

To zdanie rozstrzyga każdy spór projektowy. Praktyczny test dla każdej
proponowanej cechy:

> Skompiluj to samo dwa razy — raz w Klinie, raz ręcznie w C — i porównaj
> `objdump -d`. Jeśli instrukcje są identyczne, cecha przechodzi.
> Jeśli nie, wywal ją albo napraw.

C++ złamał tę zasadę trzy razy: konstruktory kopiujące, wyjątki,
przeciążanie operatorów. Każde z nich sprawia, że niewinna linijka robi
coś drogiego. Klin ma tego nie powtórzyć.

## Cel docelowy

Programowanie mikrokontrolerów (STM32, Cortex-M) w języku, który daje:

- struktury z metodami zamiast prefiksów `modul_funkcja_()`
- moduły i realną enkapsulację zamiast `static` i opaque pointerów
- brak `null`, błędy jako wartości
- niezmienność domyślną
- typowany dostęp do rejestrów sprzętowych, generowany automatycznie z SVD

...przy zachowaniu pełnej kontroli nad pamięcią i zerowym narzutem runtime.

## Dlaczego backend C, a nie LLVM

1. **Zasięg.** Działa na każdym MCU, dla którego istnieje kompilator C —
   łącznie z archaicznymi PIC-ami i 8051, dla których LLVM nigdy nie
   dostanie backendu. To realna nisza, której Zig i Rust nie pokrywają.
2. **Brak vendor lock-inu.** Jeśli projekt umrze, użytkownik bierze
   wygenerowany C i pracuje dalej.
3. **Interop za darmo.** Nagłówki C, biblioteki C, narzędzia C (gdb,
   objdump, valgrind) działają bez warstwy pośredniej.
4. **Prostota implementacji.** Backend C to najłatwiejsza część projektu.
   Cała trudność siedzi we frontendzie — którego potrzebowałbym tak czy
   inaczej, również celując w LLVM.

## Czym Klin NIE jest (non-goals)

- **Nie jest supersetem C.** Nie parsuje legalnego kodu C. Parsowanie
  pełnego C (preprocesor, `typedef` vs identyfikator, "lexer hack") to
  problem rzędu wielkości większy niż własna czysta gramatyka.
  Interop realizowany przez deklaracje FFI, nie przez parsowanie nagłówków.
- **Nie ma GC.** Ani domyślnie, ani opcjonalnie na start.
- **Nie ma borrow checkera.** To problem badawczy, nie kwestia zapału.
- **Nie ma runtime'u.** Żadnych goroutines, żadnego schedulera.
- **Nie ma wyjątków.**

## Inspiracje i co z nich brane

| Źródło | Co brane |
|---|---|
| **V** | `mut` (niezmienność domyślna), `pub`, brak globali, brak `null`, `!T` + `or {}` |
| **Nelua** | preprocesor zamiast generyków w rdzeniu, adnotacje `cimport`/`cexport`/`codename`, ZII |
| **Go** | `defer`, struktury z metodami bez dziedziczenia, kompozycja zamiast hierarchii |
| **Zig / Odin** | alokator jako jawny argument, nie globalna magia |

### Czego świadomie NIE brać

**Autofree z V.** Sztandarowa obietnica V — kompilator sam wstawia
`free()` w czasie kompilacji, bez GC i bez borrow checkera. Po latach
wciąż WIP, dokumentacja odradza używanie, a bywa **wolniejszy niż GC**
(klonowanie stringów O(n), żeby uniknąć wiszących wskaźników).
To empiryczny dowód, że automatyczne zarządzanie pamięcią bez GC
i bez systemu typów pilnującego czasu życia jest problemem badawczym.

**Wniosek:** deklaruj model pamięci, który na pewno zaimplementujesz,
a nie taki, który brzmi najlepiej w README.

## Sąsiedzi — warto znać przed startem

- **Nelua** — najbliższy punkt odniesienia. Kompletny, działający
  kompilator do C napisany w Lua. Warto przeczytać jego codegen.
- **nesC** — rozszerzenie C pod TinyOS, komponenty i moduły. Bezpośredni
  poprzednik idei, choć inna epoka.
- **V** — kompiluje do C, samohostowany, celowo mały kod źródłowy.
- **TinyGo** `tools/gen-device-svd` — wzorzec generatora SVD.
- **Zig / Odin** — robią to samo lepiej, ale przez LLVM.
