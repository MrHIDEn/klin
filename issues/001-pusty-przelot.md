# 001 — Pusty przelot: hello world przez cały rurociąg

**Status:** 🔜 następny
**Szacunek:** kilka wieczorów
**Zależy od:** 000

## Opis

Uruchomić **cały** rurociąg od tekstu do działającego procesu.
To najważniejszy moment projektu — potem każda cecha to dokładanie
do działającej maszyny, a nie budowa od zera.

## Zakres

Wejście `hello.kl`:

```
fn main() {
    puts("hello")
    puts("z Klina")
}
```

Wyjście `out/hello.c`:

```c
#include <stdio.h>
int main(void) {
    puts("hello");
    puts("z Klina");
    return 0;
}
```

Potem `gcc out/hello.c -o out/hello && ./out/hello`.

## Gramatyka — cała

```
program := "fn" "main" "(" ")" block
block   := "{" call* "}"
call    := ident "(" string ")"
```

## Czego świadomie NIE MA

Zmiennych, typów, wyrażeń, `if`, argumentów funkcji, więcej niż jednej
funkcji. **Żadnego type checkera.** Wygląda absurdalnie mało — o to chodzi.

## Pliki

```
bin/klin.dart
lib/token.dart
lib/lexer.dart
lib/ast.dart
lib/parser.dart
lib/emit_c.dart
```

## Kryterium ukończenia

Nie "kompiluje się", tylko:

- [ ] `dart run bin/klin.dart hello.kl` wypisuje `hello` w terminalu
- [ ] obok leży czytelny `out/hello.c`
- [ ] test poprawnego pliku
- [ ] **test pliku z błędem składni dający sensowny komunikat z numerem linii**

Ten ostatni jest ważniejszy, niż się wydaje: jeśli lekser od pierwszego
dnia nosi pozycję (linia, kolumna), wszystko potem działa. Jeśli nie —
trzeba to dokładać do każdej struktury osobno.
