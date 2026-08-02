# 001 — Empty pass-through: hello world through the full pipeline

**Status:** ✅ done
**Estimate:** a few evenings
**Depends on:** 000

## Description

Run the **entire** pipeline from source text to a working process.
This is the most important moment in the project — after this, every feature
is added to a working machine, not built from scratch.

## Scope

Input `hello.kl`:

```
fn main() {
    puts("hello")
    puts("z Klina")
}
```

Output `out/hello.c`:

```c
#include <stdio.h>
int main(void) {
    puts("hello");
    puts("z Klina");
    return 0;
}
```

Then `gcc out/hello.c -o out/hello && ./out/hello`.

## Grammar — complete

```
program := "fn" "main" "(" ")" block
block   := "{" call* "}"
call    := ident "(" string ")"
```

## What is deliberately NOT there

Variables, types, expressions, `if`, function arguments, more than one
function. **No type checker.** It looks absurdly small — that is the point.

## Files

```
bin/klin.dart
lib/token.dart
lib/lexer.dart
lib/ast.dart
lib/parser.dart
lib/emit_c.dart
```

## Completion criteria

Not just "it compiles", but:

- [x] `dart run bin/klin.dart hello.kl` prints `hello` in the terminal
- [x] a readable `out/hello.c` sits alongside it
- [x] test for a correct file
- [x] **test for a syntactically invalid file giving a sensible message with line number**

The last one matters more than it seems: if the lexer carries position
(line, column) from day one, everything else works. If not —
you have to bolt it onto every structure separately.
