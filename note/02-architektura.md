# Architektura i zasady inżynierskie

## Rurociąg

```
plik.kl
  → lekser        (tekst → tokeny, każdy z pozycją)
  → parser        (tokeny → AST, zejście rekurencyjne)
  → checker       (tablica symboli, typy, rozwiązywanie nazw)
  → codegen       (AST → jeden plik .c)
  → gcc/clang/tcc (.c → binarka)
```

## Język implementacji: Dart

Nie dlatego, że jest najlepszym narzędziem do pisania kompilatorów
(to OCaml albo Rust), tylko dlatego, że jest najlepszy **dla mnie
do tego projektu**. Projekt umrze nie na trudności technicznej, tylko
na tarciu — kiedy po tygodniowej przerwie trzeba sobie przypomnieć
składnię. Plus: skonfigurowany IntelliJ, znajomość debuggera,
`dart compile exe` daje samodzielną binarkę.

Sealed classes + pattern matching z Darta 3 to dokładnie to, czego
potrzeba na AST:

```dart
sealed class Expr {}
final class IntLit extends Expr { final int value; IntLit(this.value); }
final class Binary extends Expr {
  final Expr left, right; final String op;
  Binary(this.left, this.op, this.right);
}
```

Kompilator wymusi obsłużenie każdego wariantu w każdym `switch` —
to zastępuje połowę testów.

Ewentualne przepisanie frontendu na OCaml/Rust to decyzja na po kroku 5,
nie na teraz.

## Struktura katalogów

```
bin/klin.dart      # CLI: argv → czytaj → lex → parse → check → emit → cc → run
lib/token.dart
lib/lexer.dart
lib/ast.dart
lib/parser.dart
lib/checker.dart
lib/emit_c.dart
test/             # testy złote: pliki .kl + oczekiwane wyjście
out/              # WSZYSTKO generowane, ignorowane przez git
doc/
```

Podział na pliki od pierwszego dnia, mimo że początkowo wszystko
zmieściłoby się w jednym — za miesiąc `parser.dart` będzie miał 1500 linii
i nie chce się tego rozdzielać wstecz.

---

## Zasady, od pierwszego dnia

### Z1. Testy złote

Katalog `test/`: plik `.kl` + oczekiwane wyjście programu. Skrypt
kompiluje wszystko i porównuje. **Bez tego po trzech tygodniach
przestanie się cokolwiek zmieniać ze strachu.**

Testy błędów są ważniejsze niż testy sukcesu.

### Z2. `#line` w emisji

Od pierwszego dnia. Bez tego gdb pokazuje wygenerowany C, nie źródło
w Klinie. Dopisanie później = przepisywanie codegenu.

Konsekwencja: **lekser musi nosić pozycję (linia, kolumna) w każdym
tokenie od samego początku.** Jeśli tak jest, wszystko potem działa.
Jeśli nie — trzeba to dokładać do każdej struktury osobno.

### Z3. Wszystkie błędy łapie frontend

Jeśli gcc krzyczy na wygenerowany kod, to jest **mój** bug, nie
użytkownika. C ma być już tylko assemblerem. Użytkownik nigdy nie
powinien zobaczyć komunikatu o kodzie, którego nie napisał.

### Z4. Ręczny parser zejściem rekurencyjnym

Bez generatorów parserów. Dla języka o składni, którą sam projektuję,
ręczny parser jest szybszy w pisaniu i daje nieporównanie lepsze
komunikaty błędów.

### Z5. Kolejność deklaracji

W Klinie kolejność w pliku nie ma znaczenia. W C ma. Codegen musi sam
sortować typy topologicznie i emitować forward declarations.

### Z6. tcc podczas iteracji

`tcc` startuje w milisekundach. gcc/clang dopiero do release'u
i do pomiarów. Flaga `--cc`.

---

## Sekcje w generowanym C

Za Neluą — cztery sekcje, bo inaczej kolejność się sypie:

1. **dyrektywy** — `#include`, `#define`
2. **deklaracje** — typy, prototypy funkcji, zmienne
3. **definicje** — ciała funkcji
4. **wewnątrz funkcji** — kod lokalny

---

## Bare metal (od kroku 10)

- `-ffreestanding`, brak libc: żadnego `printf`, `malloc`, `string`
- brak GC — u nas to i tak stan domyślny, nie flaga
- startup w ASM zostaje surowym `.s` obok — tablica wektorów, reset
  handler, kopiowanie `.data`, zerowanie `.bss`. **Nie opakowywać.**
- skrypt linkera po stronie użytkownika
- `-Os`, `-ffunction-sections -fdata-sections`, `--gc-sections`
  — inaczej martwy kod z SVD wysadzi binarkę

**Nie parsować nagłówków CMSIS.** Są zbudowane z makr i bitfieldów,
których żaden prosty parser nie ugryzie. Sygnatury pisane ręcznie
jako deklaracje FFI.
