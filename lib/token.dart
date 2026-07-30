/// Pozycja w źródle (1-indeksowana linia i kolumna).
final class SourcePos {
  final int line;
  final int col;

  const SourcePos(this.line, this.col);

  @override
  String toString() => '$line:$col';
}

enum TokenKind {
  // słowa kluczowe
  fn,
  let,
  mut,
  true_,
  false_,

  // literały i nazwy
  ident,
  intLit,
  floatLit,
  string,

  // operatory i znaki
  plus,
  minus,
  star,
  slash,
  colon,
  equal,

  lParen,
  rParen,
  lBrace,
  rBrace,
  eof,
}

final class Token {
  final TokenKind kind;
  final String lexeme;
  final SourcePos pos;

  const Token(this.kind, this.lexeme, this.pos);

  @override
  String toString() => 'Token(${kind.name}, "$lexeme", $pos)';
}
