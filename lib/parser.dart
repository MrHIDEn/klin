import 'ast.dart';
import 'token.dart';

final class ParseError implements Exception {
  final String message;
  final SourcePos pos;

  const ParseError(this.message, this.pos);

  @override
  String toString() => '${pos.line}:${pos.col}: $message';
}

/// Gramatyka 001:
///   program := "fn" "main" "(" ")" block
///   block   := "{" call* "}"
///   call    := ident "(" string ")"
final class Parser {
  final List<Token> _tokens;
  int _i = 0;

  Parser(this._tokens);

  Program parse() {
    final fn = _expect(TokenKind.fn, 'oczekiwano `fn`');
    final name = _expect(TokenKind.ident, 'oczekiwano `main`');
    if (name.lexeme != 'main') {
      throw ParseError('oczekiwano `main`, dostano `${name.lexeme}`', name.pos);
    }
    _expect(TokenKind.lParen, 'oczekiwano `(`');
    _expect(TokenKind.rParen, 'oczekiwano `)`');
    final body = _block();
    _expect(TokenKind.eof, 'oczekiwano koniec pliku');
    return Program(body, fn.pos);
  }

  Block _block() {
    final open = _expect(TokenKind.lBrace, 'oczekiwano `{`');
    final calls = <Call>[];
    while (!_check(TokenKind.rBrace) && !_check(TokenKind.eof)) {
      calls.add(_call());
    }
    _expect(TokenKind.rBrace, 'oczekiwano `}`');
    return Block(calls, open.pos);
  }

  Call _call() {
    final callee = _expect(TokenKind.ident, 'oczekiwano nazwę funkcji');
    _expect(TokenKind.lParen, 'oczekiwano `(`');
    final arg = _expect(TokenKind.string, 'oczekiwano napis');
    _expect(TokenKind.rParen, 'oczekiwano `)`');
    return Call(callee.lexeme, arg.lexeme, callee.pos);
  }

  bool _check(TokenKind kind) => _current.kind == kind;

  Token get _current => _tokens[_i];

  Token _expect(TokenKind kind, String message) {
    final t = _current;
    if (t.kind != kind) {
      throw ParseError(message, t.pos);
    }
    _i++;
    return t;
  }
}
