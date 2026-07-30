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
  struct,
  pub,
  module,
  import,
  let,
  mut,
  cast,
  volatile,
  true_,
  false_,
  if_,
  else_,
  while_,
  for_,
  in_,
  return_,
  break_,
  continue_,
  defer_,
  or_,
  error_,
  asm_,

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
  percent,
  ampersand,
  atSign,
  colon,
  equal,
  equalEqual,
  bang,
  bangEqual,
  less,
  lessEqual,
  greater,
  greaterEqual,
  dot,
  dotDotLess, // ..<
  semicolon,
  comma,

  lParen,
  rParen,
  lBrace,
  rBrace,
  lBracket,
  rBracket,
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
