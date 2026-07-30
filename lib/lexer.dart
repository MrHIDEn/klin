import 'token.dart';

final class LexError implements Exception {
  final String message;
  final SourcePos pos;

  const LexError(this.message, this.pos);

  @override
  String toString() => '${pos.line}:${pos.col}: $message';
}

final class Lexer {
  final String source;
  int _i = 0;
  int _line = 1;
  int _col = 1;

  Lexer(this.source);

  List<Token> tokenize() {
    final tokens = <Token>[];
    while (true) {
      final t = _next();
      tokens.add(t);
      if (t.kind == TokenKind.eof) break;
    }
    return tokens;
  }

  Token _next() {
    _skipWhitespace();
    if (_atEnd) {
      return Token(TokenKind.eof, '', SourcePos(_line, _col));
    }

    final start = SourcePos(_line, _col);
    final c = _peek;

    if (_isIdentStart(c)) return _identOrKeyword(start);
    if (c == '"') return _string(start);

    switch (c) {
      case '(':
        _advance();
        return Token(TokenKind.lParen, '(', start);
      case ')':
        _advance();
        return Token(TokenKind.rParen, ')', start);
      case '{':
        _advance();
        return Token(TokenKind.lBrace, '{', start);
      case '}':
        _advance();
        return Token(TokenKind.rBrace, '}', start);
      default:
        throw LexError('nieoczekiwany znak `$c`', start);
    }
  }

  Token _identOrKeyword(SourcePos start) {
    final buf = StringBuffer();
    while (!_atEnd && _isIdentContinue(_peek)) {
      buf.write(_advance());
    }
    final lexeme = buf.toString();
    if (lexeme == 'fn') {
      return Token(TokenKind.fn, lexeme, start);
    }
    return Token(TokenKind.ident, lexeme, start);
  }

  Token _string(SourcePos start) {
    _advance(); // opening "
    final buf = StringBuffer();
    while (!_atEnd && _peek != '"') {
      if (_peek == '\n') {
        throw LexError('niezakończony napis', start);
      }
      if (_peek == '\\') {
        _advance();
        if (_atEnd) throw LexError('niezakończony napis', start);
        final esc = _advance();
        switch (esc) {
          case 'n':
            buf.write('\n');
          case 't':
            buf.write('\t');
          case '\\':
            buf.write('\\');
          case '"':
            buf.write('"');
          default:
            throw LexError('nieznana sekwencja ucieczki `\\$esc`', start);
        }
      } else {
        buf.write(_advance());
      }
    }
    if (_atEnd) throw LexError('niezakończony napis', start);
    _advance(); // closing "
    return Token(TokenKind.string, buf.toString(), start);
  }

  void _skipWhitespace() {
    while (!_atEnd) {
      final c = _peek;
      if (c == ' ' || c == '\t' || c == '\r') {
        _advance();
      } else if (c == '\n') {
        _advance();
      } else {
        break;
      }
    }
  }

  bool get _atEnd => _i >= source.length;

  String get _peek => source[_i];

  String _advance() {
    final c = source[_i++];
    if (c == '\n') {
      _line++;
      _col = 1;
    } else {
      _col++;
    }
    return c;
  }

  static bool _isIdentStart(String c) {
    final u = c.codeUnitAt(0);
    return (u >= 65 && u <= 90) || // A-Z
        (u >= 97 && u <= 122) || // a-z
        u == 95; // _
  }

  static bool _isIdentContinue(String c) {
    final u = c.codeUnitAt(0);
    return _isIdentStart(c) || (u >= 48 && u <= 57); // 0-9
  }
}
