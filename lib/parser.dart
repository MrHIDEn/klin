import 'ast.dart';
import 'token.dart';

final class ParseError implements Exception {
  final String message;
  final SourcePos pos;

  const ParseError(this.message, this.pos);

  @override
  String toString() => '${pos.line}:${pos.col}: $message';
}

/// Gramatyka 004:
///   program := func+ eof
///   func    := "fn" ident "(" params? ")" (":" ident)? block
///   params  := ident ":" ident ("," ident ":" ident)*
///   block   := "{" stmt* "}"
///   stmt    := let | assign | call | if | while | for | return | break
///            | continue | block
///   if      := "if" expr block ("else" (if | block))?
///   while   := "while" expr block
///   for     := "for" ident "in" expr "..<" expr block
///            | "for" [ident "=" expr] ";" [expr] ";" [ident "=" expr] block
///   return  := "return" expr?
///   call    := ident "(" (expr ("," expr)*)? ")"
///   expr    := equality
///   equality   := comparison (("==" | "!=") comparison)*
///   comparison := term (("<" | "<=" | ">" | ">=") term)*
///   term    := factor (("+" | "-") factor)*
///   factor  := unary (("*" | "/" | "%") unary)*
///   unary   := ("-" | "!") unary | primary
///   primary := INT | FLOAT | STRING | true | false | ident ["(" args? ")"]
///            | "(" expr ")"
final class Parser {
  final List<Token> _tokens;
  int _i = 0;

  Parser(this._tokens);

  Program parse() {
    final funcs = <FuncDecl>[];
    final structs = <StructDecl>[];
    while (!_check(TokenKind.eof)) {
      if (_check(TokenKind.pub)) _advance();
      if (_check(TokenKind.struct)) {
        structs.add(_struct());
      } else if (_check(TokenKind.fn)) {
        funcs.add(_func());
      } else {
        throw ParseError('oczekiwano deklarację struktury lub funkcji', _current.pos);
      }
    }
    if (funcs.isEmpty && structs.isEmpty) {
      throw ParseError('oczekiwano deklarację', _current.pos);
    }
    _expect(TokenKind.eof, 'oczekiwano koniec pliku');
    final pos = structs.isNotEmpty ? structs.first.pos : funcs.first.pos;
    return Program(structs, funcs, pos);
  }

  StructDecl _struct() {
    final keyword = _expect(TokenKind.struct, 'oczekiwano `struct`');
    final name = _expect(TokenKind.ident, 'oczekiwano nazwę struktury');
    _rejectCKeyword(name, 'nazwą struktury');
    _expect(TokenKind.lBrace, 'oczekiwano `{`');
    final fields = <FieldDecl>[];
    while (!_check(TokenKind.rBrace) && !_check(TokenKind.eof)) {
      final field = _expect(TokenKind.ident, 'oczekiwano nazwę pola');
      _rejectCKeyword(field, 'nazwą pola');
      _expect(TokenKind.colon, 'oczekiwano `:` po nazwie pola');
      final type = _expect(TokenKind.ident, 'oczekiwano typ pola');
      fields.add(FieldDecl(name: field.lexeme, typeName: type.lexeme, pos: field.pos));
    }
    _expect(TokenKind.rBrace, 'oczekiwano `}`');
    return StructDecl(name: name.lexeme, fields: fields, pos: keyword.pos);
  }

  FuncDecl _func() {
    final fn = _expect(TokenKind.fn, 'oczekiwano `fn`');
    Receiver? receiver;
    if (_check(TokenKind.lParen)) {
      _advance();
      var isMut = false;
      if (_check(TokenKind.mut)) {
        _advance();
        isMut = true;
      }
      final receiverName = _expect(TokenKind.ident, 'oczekiwano nazwę receivera');
      _rejectCKeyword(receiverName, 'nazwą receivera');
      _expect(TokenKind.colon, 'oczekiwano `:` po receiverze');
      final receiverType = _expect(TokenKind.ident, 'oczekiwano typ receivera');
      _expect(TokenKind.rParen, 'oczekiwano `)` po receiverze');
      receiver = Receiver(
        name: receiverName.lexeme,
        typeName: receiverType.lexeme,
        isMut: isMut,
        pos: receiverName.pos,
      );
    }
    final name = _expect(TokenKind.ident, 'oczekiwano nazwę funkcji');
    _rejectCKeyword(name, 'nazwą funkcji');
    _expect(TokenKind.lParen, 'oczekiwano `(`');
    final params = <Param>[];
    if (!_check(TokenKind.rParen)) {
      do {
        final paramName = _expect(TokenKind.ident, 'oczekiwano nazwę parametru');
        _rejectCKeyword(paramName, 'nazwą parametru');
        _expect(TokenKind.colon, 'oczekiwano `:` po nazwie parametru');
        final type = _expect(TokenKind.ident, 'oczekiwano nazwę typu parametru');
        params.add(
          Param(name: paramName.lexeme, typeName: type.lexeme, pos: paramName.pos),
        );
        if (!_check(TokenKind.comma)) break;
        _advance();
      } while (true);
    }
    _expect(TokenKind.rParen, 'oczekiwano `)`');

    String? returnTypeName;
    if (_check(TokenKind.colon)) {
      _advance();
      returnTypeName = _expect(
        TokenKind.ident,
        'oczekiwano nazwę typu zwracanego',
      ).lexeme;
    }
    return FuncDecl(
      name: name.lexeme,
      receiver: receiver,
      params: params,
      returnTypeName: returnTypeName,
      body: _block(),
      pos: fn.pos,
    );
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
    if (_check(TokenKind.if_)) return _ifStmt();
    if (_check(TokenKind.while_)) return _whileStmt();
    if (_check(TokenKind.for_)) return _forStmt();
    if (_check(TokenKind.return_)) return _returnStmt();
    if (_check(TokenKind.break_)) {
      final t = _advance();
      return BreakStmt(t.pos);
    }
    if (_check(TokenKind.continue_)) {
      final t = _advance();
      return ContinueStmt(t.pos);
    }
    if (_check(TokenKind.lBrace)) return BlockStmt(_block());

    if (_check(TokenKind.ident)) {
      final expr = _expr();
      if (_check(TokenKind.equal)) {
        if (expr is! NameExpr && expr is! FieldExpr) {
          throw ParseError('lewa strona przypisania musi być zmienną lub polem', expr.pos);
        }
        _advance();
        return AssignStmt(target: expr, value: _expr(), pos: expr.pos);
      }
      if (expr is CallExpr) {
        return CallStmt(callee: expr.callee, args: expr.args, pos: expr.pos);
      }
      if (expr is MethodCallExpr) return MethodCallStmt(expr);
      throw ParseError('oczekiwano przypisania `=` lub wywołania', expr.pos);
    }

    throw ParseError('oczekiwano instrukcję', _current.pos);
  }

  IfStmt _ifStmt() {
    final ifTok = _expect(TokenKind.if_, 'oczekiwano `if`');
    final cond = _expr();
    final thenBlock = _block();
    Stmt? elseBranch;
    if (_check(TokenKind.else_)) {
      _advance();
      if (_check(TokenKind.if_)) {
        elseBranch = _ifStmt();
      } else {
        elseBranch = BlockStmt(_block());
      }
    }
    return IfStmt(
      cond: cond,
      thenBlock: thenBlock,
      elseBranch: elseBranch,
      pos: ifTok.pos,
    );
  }

  WhileStmt _whileStmt() {
    final tok = _expect(TokenKind.while_, 'oczekiwano `while`');
    final cond = _expr();
    final body = _block();
    return WhileStmt(cond: cond, body: body, pos: tok.pos);
  }

  Stmt _forStmt() {
    final forTok = _expect(TokenKind.for_, 'oczekiwano `for`');

    // for i in start..<end { ... }
    // for i = 0; i < n; i = i + 1 { ... }
    // for ; cond; { ... }  /  for ;; { ... }
    if (_check(TokenKind.ident)) {
      final name = _current;
      if (_i + 1 < _tokens.length && _tokens[_i + 1].kind == TokenKind.in_) {
        _advance(); // name
        _advance(); // in
        final start = _expr();
        _expect(TokenKind.dotDotLess, 'oczekiwano `..<`');
        final end = _expr();
        final body = _block();
        return ForRangeStmt(
          name: name.lexeme,
          start: start,
          endExclusive: end,
          body: body,
          pos: forTok.pos,
        );
      }
    }

    // C-style
    String? initName;
    Expr? initExpr;
    if (!_check(TokenKind.semicolon)) {
      final name = _expect(TokenKind.ident, 'oczekiwano nazwę zmiennej pętli');
      _expect(TokenKind.equal, 'oczekiwano `=`');
      initName = name.lexeme;
      initExpr = _expr();
    }
    _expect(TokenKind.semicolon, 'oczekiwano `;`');

    Expr? cond;
    if (!_check(TokenKind.semicolon)) {
      cond = _expr();
    }
    _expect(TokenKind.semicolon, 'oczekiwano `;`');

    String? postName;
    Expr? postExpr;
    if (!_check(TokenKind.lBrace)) {
      final name = _expect(TokenKind.ident, 'oczekiwano nazwę w post-wyrażeniu');
      _expect(TokenKind.equal, 'oczekiwano `=`');
      postName = name.lexeme;
      postExpr = _expr();
    }

    final body = _block();
    return ForCStmt(
      initName: initName,
      initExpr: initExpr,
      cond: cond,
      postName: postName,
      postExpr: postExpr,
      body: body,
      pos: forTok.pos,
    );
  }

  ReturnStmt _returnStmt() {
    final tok = _expect(TokenKind.return_, 'oczekiwano `return`');
    Expr? value;
    // Bez średników: nie pożeraj następnej instrukcji (`return` + `puts(...)`
    // albo `x = ...` w kolejnej linii). `return fib(n)` w tej samej linii OK.
    if (_looksLikeReturnValue(tok.pos)) {
      value = _expr();
    }
    return ReturnStmt(value: value, pos: tok.pos);
  }

  bool _looksLikeReturnValue(SourcePos returnPos) {
    if (!_canStartExpr(_current.kind)) return false;
    if (_check(TokenKind.ident) && _i + 1 < _tokens.length) {
      final next = _tokens[_i + 1].kind;
      if (next == TokenKind.equal) {
        return false;
      }
      // Wywołanie zaczynające się w następnej linii → osobny stmt, nie wartość.
      if (next == TokenKind.lParen && _current.pos.line > returnPos.line) {
        return false;
      }
    }
    return true;
  }

  static bool _canStartExpr(TokenKind kind) => switch (kind) {
        TokenKind.intLit ||
        TokenKind.floatLit ||
        TokenKind.string ||
        TokenKind.true_ ||
        TokenKind.false_ ||
        TokenKind.ident ||
        TokenKind.lParen ||
        TokenKind.minus ||
        TokenKind.bang =>
          true,
        _ => false,
      };

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

  List<Expr> _argList() {
    _expect(TokenKind.lParen, 'oczekiwano `(`');
    final args = <Expr>[];
    if (!_check(TokenKind.rParen)) {
      args.add(_expr());
      while (_check(TokenKind.comma)) {
        _advance();
        args.add(_expr());
      }
    }
    _expect(TokenKind.rParen, 'oczekiwano `)`');
    return args;
  }

  Expr _expr() => _equality();

  Expr _equality() {
    var left = _comparison();
    while (_check(TokenKind.equalEqual) || _check(TokenKind.bangEqual)) {
      final op = _advance();
      final right = _comparison();
      left = BinaryExpr(left, op.lexeme, right, op.pos);
    }
    return left;
  }

  Expr _comparison() {
    var left = _termAdd();
    while (_check(TokenKind.less) ||
        _check(TokenKind.lessEqual) ||
        _check(TokenKind.greater) ||
        _check(TokenKind.greaterEqual)) {
      final op = _advance();
      final right = _termAdd();
      left = BinaryExpr(left, op.lexeme, right, op.pos);
    }
    return left;
  }

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
    while (_check(TokenKind.star) ||
        _check(TokenKind.slash) ||
        _check(TokenKind.percent)) {
      final op = _advance();
      final right = _unary();
      left = BinaryExpr(left, op.lexeme, right, op.pos);
    }
    return left;
  }

  Expr _unary() {
    if (_check(TokenKind.minus) || _check(TokenKind.bang)) {
      final op = _advance();
      final operand = _unary();
      return UnaryExpr(op.lexeme, operand, op.pos);
    }
    return _primary();
  }

  Expr _primary() {
    final t = _current;
    Expr expr;
    switch (t.kind) {
      case TokenKind.intLit:
        _advance();
        expr = IntLit(t.lexeme, t.pos);
        break;
      case TokenKind.floatLit:
        _advance();
        expr = FloatLit(t.lexeme, t.pos);
        break;
      case TokenKind.string:
        _advance();
        expr = StringLit(t.lexeme, t.pos);
        break;
      case TokenKind.true_:
        _advance();
        expr = BoolLit(true, t.pos);
        break;
      case TokenKind.false_:
        _advance();
        expr = BoolLit(false, t.pos);
        break;
      case TokenKind.ident:
        _advance();
        if (_check(TokenKind.lParen)) {
          _rejectCKeyword(t, 'nazwą wywołania');
          expr = CallExpr(callee: t.lexeme, args: _argList(), pos: t.pos);
        } else if (_check(TokenKind.lBrace)) {
          expr = _structLit(t);
        } else {
          expr = NameExpr(t.lexeme, t.pos);
        }
        break;
      case TokenKind.lParen:
        final open = _advance();
        final inner = _expr();
        _expect(TokenKind.rParen, 'oczekiwano `)`');
        expr = GroupExpr(inner, open.pos);
        break;
      default:
        throw ParseError('oczekiwano wyrażenie', t.pos);
    }
    while (_check(TokenKind.dot)) {
      _advance();
      final member = _expect(TokenKind.ident, 'oczekiwano nazwę pola lub metody');
      if (_check(TokenKind.lParen)) {
        expr = MethodCallExpr(
          receiver: expr,
          name: member.lexeme,
          args: _argList(),
          pos: member.pos,
        );
      } else {
        expr = FieldExpr(object: expr, name: member.lexeme, pos: member.pos);
      }
    }
    return expr;
  }

  StructLitExpr _structLit(Token typeName) {
    _expect(TokenKind.lBrace, 'oczekiwano `{`');
    if (_check(TokenKind.rBrace)) {
      _advance();
      return StructLitExpr.positional(typeName: typeName.lexeme, fields: [], pos: typeName.pos);
    }
    final isNamed = _check(TokenKind.ident) &&
        _i + 1 < _tokens.length &&
        _tokens[_i + 1].kind == TokenKind.colon;
    if (isNamed) {
      final fields = <String, Expr>{};
      do {
        final name = _expect(TokenKind.ident, 'oczekiwano nazwę pola');
        _expect(TokenKind.colon, 'oczekiwano `:` po nazwie pola');
        if (fields.containsKey(name.lexeme)) {
          throw ParseError('powtórzone pole `${name.lexeme}`', name.pos);
        }
        fields[name.lexeme] = _expr();
        if (!_check(TokenKind.comma)) break;
        _advance();
      } while (true);
      _expect(TokenKind.rBrace, 'oczekiwano `}`');
      return StructLitExpr.named(typeName: typeName.lexeme, fields: fields, pos: typeName.pos);
    }
    final fields = <Expr>[_expr()];
    while (_check(TokenKind.comma)) {
      _advance();
      fields.add(_expr());
    }
    _expect(TokenKind.rBrace, 'oczekiwano `}`');
    return StructLitExpr.positional(typeName: typeName.lexeme, fields: fields, pos: typeName.pos);
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

  void _rejectCKeyword(Token token, String role) {
    if (_cKeywords.contains(token.lexeme)) {
      throw ParseError(
        '`${token.lexeme}` jest słowem kluczowym C i nie może być $role',
        token.pos,
      );
    }
  }

  /// Słowa kluczowe C — nie mogą trafić do emisji jako identyfikatory wywołań.
  static const _cKeywords = {
    'auto',
    'break',
    'case',
    'char',
    'const',
    'continue',
    'default',
    'do',
    'double',
    'else',
    'enum',
    'extern',
    'float',
    'for',
    'goto',
    'if',
    'inline',
    'int',
    'long',
    'register',
    'restrict',
    'return',
    'short',
    'signed',
    'sizeof',
    'static',
    'struct',
    'switch',
    'typedef',
    'union',
    'unsigned',
    'void',
    'volatile',
    'while',
    '_Alignas',
    '_Alignof',
    '_Atomic',
    '_Bool',
    '_Complex',
    '_Generic',
    '_Imaginary',
    '_Noreturn',
    '_Static_assert',
    '_Thread_local',
    'bool', // C23 / <stdbool.h>
    'true',
    'false',
    'nullptr',
    'typeof',
    'typeof_unqual',
  };
}
