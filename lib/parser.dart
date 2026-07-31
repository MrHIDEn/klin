import 'ast.dart';
import 'lexer.dart';
import 'token.dart';

final class ParseError implements Exception {
  final String message;
  final SourcePos pos;

  const ParseError(this.message, this.pos);

  @override
  String toString() => '${pos.line}:${pos.col}: $message';
}

/// Grammar 004:
///   program := func+ eof
///   func    := "fn" ident "(" params? ")" (":" ident)? block
///   params  := ident ":" ident ("," ident ":" ident)*
///   block   := "{" stmt* "}"
///   stmt    := let | assign | call | if | while | for | return | break
///            | continue | defer | block
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
  final Set<String> _importedModules = {};

  Parser(this._tokens);

  Program parse() {
    final unit = parseUnit();
    return Program(unit.structs, unit.funcs, unit.pos);
  }

  /// Parse a single expression (used for `${…}` interpolation slots).
  Expr parseExpression() {
    final expr = _expr();
    if (!_check(TokenKind.eof)) {
      throw ParseError(
        'unexpected token `${_current.lexeme}` in interpolation expression',
        _current.pos,
      );
    }
    return expr;
  }

  ModuleUnit parseUnit() {
    final funcs = <FuncDecl>[];
    final structs = <StructDecl>[];
    final decls = <Object>[];
    String? declaredName;
    final imports = <String>[];
    if (_check(TokenKind.module)) {
      _advance();
      declaredName = _expect(TokenKind.ident, 'expected module name').lexeme;
    }
    while (_check(TokenKind.import)) {
      _advance();
      final name = _expect(TokenKind.ident, 'expected imported module name');
      imports.add(name.lexeme);
      _importedModules.add(name.lexeme);
    }
    while (!_check(TokenKind.eof)) {
      final attrs = _attrs();
      var isPub = false;
      if (_check(TokenKind.pub)) {
        _advance();
        isPub = true;
      }
      if (_check(TokenKind.struct)) {
        final decl = _struct(isPub, attrs);
        structs.add(decl);
        decls.add(decl);
      } else if (_check(TokenKind.fn)) {
        final decl = _func(isPub, attrs);
        funcs.add(decl);
        decls.add(decl);
      } else {
        throw ParseError(
            'expected struct or function declaration', _current.pos);
      }
    }
    if (funcs.isEmpty && structs.isEmpty) {
      throw ParseError('expected declaration', _current.pos);
    }
    _expect(TokenKind.eof, 'expected end of file');
    final pos = structs.isNotEmpty
        ? structs.first.pos
        : funcs.isNotEmpty
            ? funcs.first.pos
            : _current.pos;
    return ModuleUnit(
      declaredName: declaredName,
      imports: imports,
      structs: structs,
      funcs: funcs,
      decls: decls,
      pos: pos,
    );
  }

  List<Attr> _attrs() {
    final attrs = <Attr>[];
    while (_check(TokenKind.atSign)) {
      _advance();
      _expect(TokenKind.lBracket, 'expected `[` after `@`');
      do {
        final name = _expect(TokenKind.ident, 'expected attribute name');
        String? arg;
        if (_check(TokenKind.lParen)) {
          _advance();
          arg = _expect(TokenKind.string, 'expected attribute string').lexeme;
          _expect(TokenKind.rParen, 'expected `)` after attribute string');
        }
        attrs.add(Attr(name.lexeme, arg, name.pos));
        if (!_check(TokenKind.comma)) break;
        _advance();
      } while (true);
      _expect(TokenKind.rBracket, 'expected `]` after attributes');
    }
    return attrs;
  }

  StructDecl _struct(bool isPub, List<Attr> attrs) {
    final keyword = _expect(TokenKind.struct, 'oczekiwano `struct`');
    final name = _expect(TokenKind.ident, 'expected struct name');
    _rejectCKeyword(name, 'a struct name');
    _expect(TokenKind.lBrace, 'oczekiwano `{`');
    final fields = <FieldDecl>[];
    while (!_check(TokenKind.rBrace) && !_check(TokenKind.eof)) {
      final field = _expect(TokenKind.ident, 'expected field name');
      _rejectCKeyword(field, 'a field name');
      _expect(TokenKind.colon, 'expected `:` after field name');
      fields.add(
          FieldDecl(name: field.lexeme, typeName: _typeName(), pos: field.pos));
    }
    _expect(TokenKind.rBrace, 'oczekiwano `}`');
    return StructDecl(
      name: name.lexeme,
      fields: fields,
      attrs: attrs,
      pos: keyword.pos,
      isPub: isPub,
    );
  }

  FuncDecl _func(bool isPub, List<Attr> attrs) {
    final fn = _expect(TokenKind.fn, 'oczekiwano `fn`');
    Receiver? receiver;
    if (_check(TokenKind.lParen)) {
      _advance();
      var isMut = false;
      if (_check(TokenKind.mut)) {
        _advance();
        isMut = true;
      }
      final receiverName = _expect(TokenKind.ident, 'expected receiver name');
      _rejectCKeyword(receiverName, 'a receiver name');
      _expect(TokenKind.colon, 'expected `:` after receiver');
      final receiverType = _typeName();
      _expect(TokenKind.rParen, 'expected `)` after receiver');
      receiver = Receiver(
        name: receiverName.lexeme,
        typeName: receiverType,
        isMut: isMut,
        pos: receiverName.pos,
      );
    }
    final name = _expect(TokenKind.ident, 'expected function name');
    _rejectCKeyword(name, 'a function name');
    _expect(TokenKind.lParen, 'oczekiwano `(`');
    final params = <Param>[];
    if (!_check(TokenKind.rParen)) {
      do {
        final paramName = _expect(TokenKind.ident, 'expected parameter name');
        _rejectCKeyword(paramName, 'a parameter name');
        _expect(TokenKind.colon, 'expected `:` after parameter name');
        final type = _typeName();
        params.add(
          Param(name: paramName.lexeme, typeName: type, pos: paramName.pos),
        );
        if (!_check(TokenKind.comma)) break;
        _advance();
      } while (true);
    }
    _expect(TokenKind.rParen, 'oczekiwano `)`');

    String? returnTypeName;
    if (_check(TokenKind.colon)) {
      _advance();
      returnTypeName = _typeName();
    }
    return FuncDecl(
      name: name.lexeme,
      receiver: receiver,
      params: params,
      returnTypeName: returnTypeName,
      body: attrs.any((attr) => attr.name == 'cimport') ? null : _block(),
      pos: fn.pos,
      attrs: attrs,
      isPub: isPub,
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
    if (_check(TokenKind.defer_)) return _deferStmt();
    if (_check(TokenKind.asm_)) return _asmStmt();
    if (_check(TokenKind.break_)) {
      final t = _advance();
      return BreakStmt(t.pos);
    }
    if (_check(TokenKind.continue_)) {
      final t = _advance();
      return ContinueStmt(t.pos);
    }
    if (_check(TokenKind.lBrace)) return BlockStmt(_block());

    if (_canStartExpr(_current.kind)) {
      final expr = _expr();
      return _stmtFromExpr(expr);
    }

    throw ParseError('expected statement', _current.pos);
  }

  AsmStmt _asmStmt() {
    final keyword = _expect(TokenKind.asm_, 'oczekiwano `asm`');
    _expect(TokenKind.lParen, 'oczekiwano `(` po `asm`');
    final code = _expect(TokenKind.string, 'oczekiwano napis instrukcji asm');
    _expect(TokenKind.rParen, 'oczekiwano `)` po instrukcji asm');
    return AsmStmt(code.lexeme, keyword.pos);
  }

  Stmt _stmtFromExpr(Expr expr) {
    if (_check(TokenKind.equal)) {
      if (expr is! NameExpr &&
          expr is! FieldExpr &&
          expr is! IndexExpr &&
          !(expr is UnaryExpr && expr.op == '*')) {
        throw ParseError(
            'left side of assignment must be assignable', expr.pos);
      }
      _advance();
      return AssignStmt(target: expr, value: _expr(), pos: expr.pos);
    }
    if (expr is CallExpr) {
      return CallStmt(
        moduleName: expr.moduleName,
        callee: expr.callee,
        args: expr.args,
        pos: expr.pos,
      );
    }
    if (expr is MethodCallExpr) return MethodCallStmt(expr);
    throw ParseError('expected assignment `=` or call', expr.pos);
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
      final name = _expect(TokenKind.ident, 'expected loop variable name');
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
      final name = _expect(TokenKind.ident, 'expected name in post expression');
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
    // Without semicolons, do not consume the following statement (`return` plus
    // `puts(...)` or `x = ...` on the next line). `return fib(n)` on one line is valid.
    if (_looksLikeReturnValue(tok.pos)) {
      value = _expr();
    }
    return ReturnStmt(value: value, pos: tok.pos);
  }

  DeferStmt _deferStmt() {
    final tok = _expect(TokenKind.defer_, 'oczekiwano `defer`');
    return DeferStmt(body: _stmt(), pos: tok.pos);
  }

  bool _looksLikeReturnValue(SourcePos returnPos) {
    if (!_canStartExpr(_current.kind)) return false;
    if (_check(TokenKind.ident) && _i + 1 < _tokens.length) {
      final next = _tokens[_i + 1].kind;
      if (next == TokenKind.equal) {
        return false;
      }
      // A call starting on the next line is a separate statement, not a value.
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
        TokenKind.lBracket ||
        TokenKind.minus ||
        TokenKind.bang ||
        TokenKind.star ||
        TokenKind.ampersand ||
        TokenKind.cast ||
        TokenKind.error_ =>
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
    final name = _expect(TokenKind.ident, 'expected variable name');
    _rejectCKeyword(name, 'a variable name');
    String? typeName;
    if (_check(TokenKind.colon)) {
      _advance();
      typeName = _typeName();
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

  Expr _expr() {
    var result = _equality();
    while (_check(TokenKind.or_)) {
      final op = _advance();
      result = OrExpr(result, _orBlock(), op.pos);
    }
    return result;
  }

  OrBlock _orBlock() {
    final open = _expect(TokenKind.lBrace, 'oczekiwano `{` po `or`');
    final stmts = <Stmt>[];
    while (!_check(TokenKind.rBrace) && !_check(TokenKind.eof)) {
      if (_canStartExpr(_current.kind)) {
        final expr = _expr();
        if (_check(TokenKind.rBrace)) {
          _advance();
          return OrBlock(stmts, expr, open.pos);
        }
        stmts.add(_stmtFromExpr(expr));
      } else {
        stmts.add(_stmt());
      }
    }
    throw ParseError('`or` block requires a final expression', _current.pos);
  }

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
    while ((_check(TokenKind.star) ||
            _check(TokenKind.slash) ||
            _check(TokenKind.percent)) &&
        _current.pos.line == left.pos.line) {
      final op = _advance();
      final right = _unary();
      left = BinaryExpr(left, op.lexeme, right, op.pos);
    }
    return left;
  }

  Expr _unary() {
    if (_check(TokenKind.minus) ||
        _check(TokenKind.bang) ||
        _check(TokenKind.star) ||
        _check(TokenKind.ampersand)) {
      final op = _advance();
      final operand = _unary();
      return UnaryExpr(op.lexeme, operand, op.pos);
    }
    return _postfix();
  }

  Expr _postfix() {
    var expr = _primary();
    while (_check(TokenKind.bang)) {
      final bang = _advance();
      expr = PropagateExpr(expr, bang.pos);
    }
    return expr;
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
        expr = _stringLitOrInterp(t);
        break;
      case TokenKind.true_:
        _advance();
        expr = BoolLit(true, t.pos);
        break;
      case TokenKind.false_:
        _advance();
        expr = BoolLit(false, t.pos);
        break;
      case TokenKind.error_:
        _advance();
        _expect(TokenKind.lParen, 'oczekiwano `(` po `error`');
        final code = _expr();
        _expect(TokenKind.rParen, 'expected `)` after error code');
        expr = ErrorExpr(code, t.pos);
        break;
      case TokenKind.ident:
        _advance();
        if (_check(TokenKind.dot) &&
            _i + 2 < _tokens.length &&
            _tokens[_i + 1].kind == TokenKind.ident &&
            _importedModules.contains(t.lexeme)) {
          _advance();
          final member =
              _expect(TokenKind.ident, 'expected module symbol name');
          if (_check(TokenKind.lParen)) {
            expr = CallExpr(
              moduleName: t.lexeme,
              callee: member.lexeme,
              args: _argList(),
              pos: t.pos,
            );
          } else if (_check(TokenKind.lBrace)) {
            expr = _structLit(member, moduleName: t.lexeme);
          } else {
            throw ParseError('expected call or struct literal', member.pos);
          }
        } else if (_check(TokenKind.lParen)) {
          _rejectCKeyword(t, 'a call name');
          expr = CallExpr(callee: t.lexeme, args: _argList(), pos: t.pos);
        } else if (_check(TokenKind.lBrace)) {
          expr = _structLit(t);
        } else {
          expr = NameExpr(t.lexeme, t.pos);
        }
        break;
      case TokenKind.lBracket:
        _advance();
        final elements = <Expr>[];
        if (!_check(TokenKind.rBracket)) {
          elements.add(_expr());
          while (_check(TokenKind.comma)) {
            _advance();
            elements.add(_expr());
          }
        }
        _expect(TokenKind.rBracket, 'expected `]` after array literal');
        expr = ArrayLitExpr(elements: elements, pos: t.pos);
        break;
      case TokenKind.cast:
        _advance();
        _expect(TokenKind.lParen, 'oczekiwano `(` po `cast`');
        final typeName = _typeName();
        _expect(TokenKind.comma, 'oczekiwano `,` po typie castowania');
        final value = _expr();
        _expect(TokenKind.rParen, 'oczekiwano `)` po castowaniu');
        expr = CastExpr(typeName: typeName, expr: value, pos: t.pos);
        break;
      case TokenKind.lParen:
        final open = _advance();
        final inner = _expr();
        _expect(TokenKind.rParen, 'oczekiwano `)`');
        expr = GroupExpr(inner, open.pos);
        break;
      default:
        throw ParseError('expected expression', t.pos);
    }
    while (_check(TokenKind.dot) || _check(TokenKind.lBracket)) {
      if (_check(TokenKind.lBracket)) {
        final bracket = _advance();
        if (_check(TokenKind.colon)) {
          _advance();
          _expect(TokenKind.rBracket, 'oczekiwano `]` po `:`');
          expr = SliceFromExpr(array: expr, pos: bracket.pos);
        } else {
          final index = _expr();
          _expect(TokenKind.rBracket, 'oczekiwano `]` po indeksie');
          expr = IndexExpr(object: expr, index: index, pos: bracket.pos);
        }
        continue;
      }
      _advance();
      final member = _expect(TokenKind.ident, 'expected field name lub metody');
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

  StructLitExpr _structLit(Token typeName, {String? moduleName}) {
    _expect(TokenKind.lBrace, 'oczekiwano `{`');
    if (_check(TokenKind.rBrace)) {
      _advance();
      return StructLitExpr.positional(
        moduleName: moduleName,
        typeName: typeName.lexeme,
        fields: [],
        pos: typeName.pos,
      );
    }
    final isNamed = _check(TokenKind.ident) &&
        _i + 1 < _tokens.length &&
        _tokens[_i + 1].kind == TokenKind.colon;
    if (isNamed) {
      final fields = <String, Expr>{};
      do {
        final name = _expect(TokenKind.ident, 'expected field name');
        _expect(TokenKind.colon, 'expected `:` after field name');
        if (fields.containsKey(name.lexeme)) {
          throw ParseError('duplicate field `${name.lexeme}`', name.pos);
        }
        fields[name.lexeme] = _expr();
        if (!_check(TokenKind.comma)) break;
        _advance();
      } while (true);
      _expect(TokenKind.rBrace, 'oczekiwano `}`');
      return StructLitExpr.named(
        moduleName: moduleName,
        typeName: typeName.lexeme,
        fields: fields,
        pos: typeName.pos,
      );
    }
    final fields = <Expr>[_expr()];
    while (_check(TokenKind.comma)) {
      _advance();
      fields.add(_expr());
    }
    _expect(TokenKind.rBrace, 'oczekiwano `}`');
    return StructLitExpr.positional(
      moduleName: moduleName,
      typeName: typeName.lexeme,
      fields: fields,
      pos: typeName.pos,
    );
  }

  Expr _stringLitOrInterp(Token t) {
    final s = t.lexeme;
    if (!_stringHasInterp(s)) {
      return StringLit(s.replaceAll(kInterpEscapedDollar, '\$'), t.pos);
    }
    return _parseInterpolatedString(s, t.pos);
  }

  bool _stringHasInterp(String s) {
    for (var i = 0; i < s.length; i++) {
      if (s.codeUnitAt(i) == kInterpEscapedDollar.codeUnitAt(0)) continue;
      if (s[i] == '\$') return true;
    }
    return false;
  }

  bool _isIdentStartChar(String c) {
    final u = c.codeUnitAt(0);
    return (u >= 65 && u <= 90) || (u >= 97 && u <= 122) || u == 95;
  }

  bool _isIdentContChar(String c) {
    final u = c.codeUnitAt(0);
    return _isIdentStartChar(c) || (u >= 48 && u <= 57);
  }

  InterpolatedStringExpr _parseInterpolatedString(String s, SourcePos pos) {
    final parts = <InterpPart>[];
    final text = StringBuffer();
    void flushText() {
      if (text.isNotEmpty) {
        parts.add(InterpText(text.toString()));
        text.clear();
      }
    }

    var i = 0;
    while (i < s.length) {
      final c = s[i];
      if (c == kInterpEscapedDollar) {
        text.write('\$');
        i++;
        continue;
      }
      if (c == '\$') {
        if (i + 1 < s.length && s[i + 1] == '{') {
          flushText();
          i += 2;
          final contentStart = i;
          var depth = 1;
          var paren = 0;
          var formatColon = -1;
          while (i < s.length && depth > 0) {
            final ch = s[i];
            if (ch == '(') {
              paren++;
            } else if (ch == ')') {
              if (paren > 0) paren--;
            } else if (ch == '{') {
              depth++;
            } else if (ch == '}') {
              depth--;
              if (depth == 0) break;
            } else if (ch == ':' &&
                depth == 1 &&
                paren == 0 &&
                formatColon < 0) {
              formatColon = i;
            }
            i++;
          }
          if (depth != 0) {
            throw ParseError('unclosed `\${` in string', pos);
          }
          final exprEnd = formatColon >= 0 ? formatColon : i;
          final exprSrc = s.substring(contentStart, exprEnd).trim();
          if (exprSrc.isEmpty) {
            throw ParseError('empty interpolation expression', pos);
          }
          String? format;
          if (formatColon >= 0) {
            format = s.substring(formatColon + 1, i);
            if (format.isEmpty) {
              throw ParseError('empty format in `\${…:}`', pos);
            }
          }
          final slotExpr =
              Parser(Lexer(exprSrc).tokenize()).parseExpression();
          parts.add(InterpSlot(slotExpr, format));
          i++; // skip closing }
          continue;
        }
        if (i + 1 < s.length && _isIdentStartChar(s[i + 1])) {
          flushText();
          i++;
          final start = i;
          i++;
          while (i < s.length && _isIdentContChar(s[i])) {
            i++;
          }
          final name = s.substring(start, i);
          parts.add(InterpSlot(NameExpr(name, pos), null));
          continue;
        }
        throw ParseError(
          'lonely `\$` in string — use `\\\$` for a literal dollar, '
          'or `\$name` / `\${expr}` for interpolation',
          pos,
        );
      }
      text.write(c);
      i++;
    }
    flushText();
    if (parts.isEmpty) {
      return InterpolatedStringExpr([InterpText('')], pos);
    }
    return InterpolatedStringExpr(parts, pos);
  }

  String _typeName() {
    if (_check(TokenKind.bang)) {
      _advance();
      return '!${_typeName()}';
    }
    if (_check(TokenKind.fn)) {
      _advance();
      _expect(TokenKind.lParen, 'expected `(` after `fn` in function type');
      final params = <String>[];
      if (!_check(TokenKind.rParen)) {
        params.add(_typeName());
        while (_check(TokenKind.comma)) {
          _advance();
          params.add(_typeName());
        }
      }
      _expect(TokenKind.rParen, 'expected `)` after function type parameters');
      var ret = 'void';
      if (_check(TokenKind.colon)) {
        _advance();
        ret = _typeName();
      }
      return 'fn(${params.join(',') }):$ret';
    }
    if (_check(TokenKind.star)) {
      _advance();
      var result = '*';
      if (_check(TokenKind.mut)) {
        _advance();
        result += 'mut ';
      }
      if (_check(TokenKind.volatile)) {
        _advance();
        result += 'volatile ';
      }
      return '$result${_typeName()}';
    }
    if (_check(TokenKind.lBracket)) {
      _advance();
      if (_check(TokenKind.rBracket)) {
        _advance();
        return '[]${_typeName()}';
      }
      final length =
          _expect(TokenKind.intLit, 'expected array length in `[...]`');
      _expect(TokenKind.rBracket, 'expected `]` after array length');
      return '[${length.lexeme}]${_typeName()}';
    }
    final first = _expect(TokenKind.ident, 'expected type name');
    if (!_check(TokenKind.dot)) return first.lexeme;
    _advance();
    final second = _expect(TokenKind.ident, 'expected type name po `.`');
    return '${first.lexeme}.${second.lexeme}';
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
        '`${token.lexeme}` is a C keyword and cannot be $role',
        token.pos,
      );
    }
  }

  /// C keywords cannot be emitted as call identifiers.
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
