# Klin

Język systemowy kompilowany do C. Backend: jeden czytelny plik .c,
potem gcc/clang/tcc. Kompilator w Darcie.

Kontekst projektu: @note/00-idea.md
Decyzje projektowe:  @note/01-decyzje.md
Architektura i zasady: @note/02-architektura.md
Roadmapa: @issues/sorted.md

## Zasady, które obowiązują zawsze

- Zasada nadrzędna: żadnej ukrytej alokacji, żadnego ukrytego przepływu
  sterowania, żadnego ukrytego kosztu. Jeśli cecha nie znika w emisji do C,
  prawdopodobnie ją łamie.
- Parser ręczny, zejście rekurencyjne. Nie proponuj generatorów parserów.
- Każdy token nosi pozycję (linia, kolumna). Emisja zawiera #line.
- Wszystkie błędy łapie frontend — gcc nigdy nie powinien krzyczeć na
  wygenerowany kod.
- Nie rozszerzaj zakresu bieżącego kroku z issues/sorted.md.
