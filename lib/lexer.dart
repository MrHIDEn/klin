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
    if (_isDigit(c)) return _number(start);
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
      case '[':
        _advance();
        return Token(TokenKind.lBracket, '[', start);
      case ']':
        _advance();
        return Token(TokenKind.rBracket, ']', start);
      case '+':
        _advance();
        return Token(TokenKind.plus, '+', start);
      case '-':
        _advance();
        return Token(TokenKind.minus, '-', start);
      case '*':
        _advance();
        return Token(TokenKind.star, '*', start);
      case '/':
        _advance();
        return Token(TokenKind.slash, '/', start);
      case '%':
        _advance();
        return Token(TokenKind.percent, '%', start);
      case '&':
        _advance();
        return Token(TokenKind.ampersand, '&', start);
      case '@':
        _advance();
        return Token(TokenKind.atSign, '@', start);
      case ':':
        _advance();
        if (!_atEnd && _peek == '=') {
          _advance();
          return Token(TokenKind.colonEqual, ':=', start);
        }
        return Token(TokenKind.colon, ':', start);
      case ';':
        _advance();
        return Token(TokenKind.semicolon, ';', start);
      case ',':
        _advance();
        return Token(TokenKind.comma, ',', start);
      case '=':
        _advance();
        if (!_atEnd && _peek == '=') {
          _advance();
          return Token(TokenKind.equalEqual, '==', start);
        }
        return Token(TokenKind.equal, '=', start);
      case '!':
        _advance();
        if (!_atEnd && _peek == '=') {
          _advance();
          return Token(TokenKind.bangEqual, '!=', start);
        }
        return Token(TokenKind.bang, '!', start);
      case '<':
        _advance();
        if (!_atEnd && _peek == '=') {
          _advance();
          return Token(TokenKind.lessEqual, '<=', start);
        }
        return Token(TokenKind.less, '<', start);
      case '>':
        _advance();
        if (!_atEnd && _peek == '=') {
          _advance();
          return Token(TokenKind.greaterEqual, '>=', start);
        }
        return Token(TokenKind.greater, '>', start);
      case '.':
        // ..<
        if (_i + 2 < source.length &&
            source[_i + 1] == '.' &&
            source[_i + 2] == '<') {
          _advance();
          _advance();
          _advance();
          return Token(TokenKind.dotDotLess, '..<', start);
        }
        _advance();
        return Token(TokenKind.dot, '.', start);
      default:
        throw LexError('unexpected character `$c`', start);
    }
  }

  Token _identOrKeyword(SourcePos start) {
    final buf = StringBuffer();
    while (!_atEnd && _isIdentContinue(_peek)) {
      buf.write(_advance());
    }
    final lexeme = buf.toString();
    return switch (lexeme) {
      'fn' => Token(TokenKind.fn, lexeme, start),
      'struct' => Token(TokenKind.struct, lexeme, start),
      'pub' => Token(TokenKind.pub, lexeme, start),
      'module' => Token(TokenKind.module, lexeme, start),
      'import' => Token(TokenKind.import, lexeme, start),
      'let' => Token(TokenKind.let, lexeme, start),
      'mut' => Token(TokenKind.mut, lexeme, start),
      'cast' => Token(TokenKind.cast, lexeme, start),
      'volatile' => Token(TokenKind.volatile, lexeme, start),
      'true' => Token(TokenKind.true_, lexeme, start),
      'false' => Token(TokenKind.false_, lexeme, start),
      'if' => Token(TokenKind.if_, lexeme, start),
      'else' => Token(TokenKind.else_, lexeme, start),
      'while' => Token(TokenKind.while_, lexeme, start),
      'for' => Token(TokenKind.for_, lexeme, start),
      'in' => Token(TokenKind.in_, lexeme, start),
      'return' => Token(TokenKind.return_, lexeme, start),
      'break' => Token(TokenKind.break_, lexeme, start),
      'continue' => Token(TokenKind.continue_, lexeme, start),
      'defer' => Token(TokenKind.defer_, lexeme, start),
      'or' => Token(TokenKind.or_, lexeme, start),
      'error' => Token(TokenKind.error_, lexeme, start),
      'asm' => Token(TokenKind.asm_, lexeme, start),
      _ => Token(TokenKind.ident, lexeme, start),
    };
  }

  Token _number(SourcePos start) {
    final buf = StringBuffer();
    if (_peek == '0' &&
        _i + 1 < source.length &&
        (source[_i + 1] == 'x' || source[_i + 1] == 'X')) {
      buf.write(_advance());
      buf.write(_advance());
      if (_atEnd || !_isHexDigit(_peek)) {
        throw LexError('expected hexadecimal digit after `0x`', start);
      }
      while (!_atEnd && (_isHexDigit(_peek) || _peek == '_')) {
        buf.write(_advance());
      }
      return Token(TokenKind.intLit, buf.toString(), start);
    }
    while (!_atEnd && (_isDigit(_peek) || _peek == '_')) {
      buf.write(_advance());
    }
    if (!_atEnd &&
        _peek == '.' &&
        _i + 1 < source.length &&
        _isDigit(source[_i + 1])) {
      buf.write(_advance()); // .
      while (!_atEnd && (_isDigit(_peek) || _peek == '_')) {
        buf.write(_advance());
      }
      return Token(TokenKind.floatLit, buf.toString(), start);
    }
    return Token(TokenKind.intLit, buf.toString(), start);
  }

  Token _string(SourcePos start) {
    _advance(); // opening "
    final buf = StringBuffer();
    while (!_atEnd && _peek != '"') {
      if (_peek == '\n') {
        throw LexError('unterminated string', start);
      }
      if (_peek == '\\') {
        _advance();
        if (_atEnd) throw LexError('unterminated string', start);
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
          case '\$':
            // Literal `$` in an interpolated string (see [kInterpEscapedDollar]).
            buf.write('\u{E000}');
          default:
            throw LexError('nieznana sekwencja ucieczki `\\$esc`', start);
        }
      } else {
        buf.write(_advance());
      }
    }
    if (_atEnd) throw LexError('unterminated string', start);
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
      } else if (c == '/' && _i + 1 < source.length && source[_i + 1] == '/') {
        while (!_atEnd && _peek != '\n') {
          _advance();
        }
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
    return _isIdentStart(c) || _isDigit(c);
  }

  static bool _isDigit(String c) {
    final u = c.codeUnitAt(0);
    return u >= 48 && u <= 57;
  }

  static bool _isHexDigit(String c) {
    final u = c.codeUnitAt(0);
    return _isDigit(c) || (u >= 65 && u <= 70) || (u >= 97 && u <= 102);
  }
}
