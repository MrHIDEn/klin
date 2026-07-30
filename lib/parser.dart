import 'ast.dart';
import 'token.dart';

final class ParseError implements Exception {
  final String message;
  final SourcePos pos;

  const ParseError(this.message, this.pos);

  @override
  String toString() => '${pos.line}:${pos.col}: $message';
}

/// Gramatyka 002:
///   program := "fn" "main" "(" ")" block
///   block   := "{" stmt* "}"
///   stmt    := let_stmt | assign_stmt | call_stmt | block
///   let_stmt := "let" "mut"? ident (":" ident)? ("=" expr)?
///   assign_stmt := ident "=" expr
///   call_stmt := ident "(" string ")"
///   expr := term (("+" | "-") term)*
///   term := unary (("*" | "/") unary)*
///   unary := "-" unary | primary
///   primary := INT | FLOAT | true | false | ident | "(" expr ")"
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
    final stmts = <Stmt>[];
    while (!_check(TokenKind.rBrace) && !_check(TokenKind.eof)) {
      stmts.add(_stmt());
    }
    _expect(TokenKind.rBrace, 'oczekiwano `}`');
    return Block(stmts, open.pos);
  }

  Stmt _stmt() {
    if (_check(TokenKind.let)) return _letStmt();
    if (_check(TokenKind.lBrace)) return BlockStmt(_block());

    if (_check(TokenKind.ident)) {
      final name = _current;
      if (_i + 1 < _tokens.length && _tokens[_i + 1].kind == TokenKind.equal) {
        _advance(); // name
        _advance(); // =
        final value = _expr();
        return AssignStmt(name: name.lexeme, value: value, pos: name.pos);
      }
      if (_i + 1 < _tokens.length && _tokens[_i + 1].kind == TokenKind.lParen) {
        return _callStmt();
      }
      throw ParseError(
        'oczekiwano przypisania `=` lub wywołania `(`',
        name.pos,
      );
    }

    throw ParseError('oczekiwano instrukcję', _current.pos);
  }

  LetStmt _letStmt() {
    final letTok = _expect(TokenKind.let, 'oczekiwano `let`');
    var isMut = false;
    if (_check(TokenKind.mut)) {
      _advance();
      isMut = true;
    }
    final name = _expect(TokenKind.ident, 'oczekiwano nazwę zmiennej');
    String? typeName;
    if (_check(TokenKind.colon)) {
      _advance();
      final ty = _expect(TokenKind.ident, 'oczekiwano nazwę typu');
      typeName = ty.lexeme;
    }
    Expr? init;
    if (_check(TokenKind.equal)) {
      _advance();
      init = _expr();
    }
    return LetStmt(
      isMut: isMut,
      name: name.lexeme,
      typeName: typeName,
      init: init,
      pos: letTok.pos,
    );
  }

  CallStmt _callStmt() {
    final callee = _expect(TokenKind.ident, 'oczekiwano nazwę funkcji');
    _expect(TokenKind.lParen, 'oczekiwano `(`');
    final arg = _expect(TokenKind.string, 'oczekiwano napis');
    _expect(TokenKind.rParen, 'oczekiwano `)`');
    return CallStmt(
      callee: callee.lexeme,
      argument: arg.lexeme,
      pos: callee.pos,
    );
  }

  Expr _expr() => _termAdd();

  Expr _termAdd() {
    var left = _termMul();
    while (_check(TokenKind.plus) || _check(TokenKind.minus)) {
      final op = _advance();
      final right = _termMul();
      left = BinaryExpr(left, op.lexeme, right, op.pos);
    }
    return left;
  }

  Expr _termMul() {
    var left = _unary();
    while (_check(TokenKind.star) || _check(TokenKind.slash)) {
      final op = _advance();
      final right = _unary();
      left = BinaryExpr(left, op.lexeme, right, op.pos);
    }
    return left;
  }

  Expr _unary() {
    if (_check(TokenKind.minus)) {
      final op = _advance();
      final operand = _unary();
      return UnaryExpr(op.lexeme, operand, op.pos);
    }
    return _primary();
  }

  Expr _primary() {
    final t = _current;
    switch (t.kind) {
      case TokenKind.intLit:
        _advance();
        return IntLit(t.lexeme, t.pos);
      case TokenKind.floatLit:
        _advance();
        return FloatLit(t.lexeme, t.pos);
      case TokenKind.true_:
        _advance();
        return BoolLit(true, t.pos);
      case TokenKind.false_:
        _advance();
        return BoolLit(false, t.pos);
      case TokenKind.ident:
        _advance();
        return NameExpr(t.lexeme, t.pos);
      case TokenKind.lParen:
        final open = _advance();
        final inner = _expr();
        _expect(TokenKind.rParen, 'oczekiwano `)`');
        return GroupExpr(inner, open.pos);
      default:
        throw ParseError('oczekiwano wyrażenie', t.pos);
    }
  }

  bool _check(TokenKind kind) => _current.kind == kind;

  Token get _current => _tokens[_i];

  Token _advance() {
    final t = _current;
    if (t.kind != TokenKind.eof) _i++;
    return t;
  }

  Token _expect(TokenKind kind, String message) {
    final t = _current;
    if (t.kind != kind) {
      throw ParseError(message, t.pos);
    }
    _i++;
    return t;
  }
}
