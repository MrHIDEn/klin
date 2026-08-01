import 'ast.dart';
import 'lexer.dart';
import 'parser.dart';

/// Canonical Klin style (issue 033): 4 spaces, K&R braces, Go-like spacing.
///
/// Comments are dropped (lexer skips them) — follow-up for comment-preserving fmt.
/// Sources with `$…` macros must be formatted after preprocess, or not at all.
const indentUnit = '    ';

/// Formats a Klin source unit. Throws [LexError] / [ParseError] on invalid input.
String formatSource(String source) {
  final unit = Parser(Lexer(source).tokenize()).parseUnit();
  return formatUnit(unit);
}

String formatUnit(ModuleUnit unit) {
  final buf = StringBuffer();
  var first = true;

  void blankBefore() {
    if (!first) buf.writeln();
    first = false;
  }

  if (unit.declaredName != null) {
    buf.writeln('module ${unit.declaredName}');
    first = false;
  }
  for (final imp in unit.imports) {
    final spec = imp.isPath ? '"${imp.spec}"' : imp.spec;
    final alias = imp.alias == null ? '' : ' ${imp.alias}';
    buf.writeln('import $spec$alias');
    first = false;
  }
  if (unit.declaredName != null || unit.imports.isNotEmpty) {
    buf.writeln();
    first = true; // next decl starts a new "group" without extra blank before first
  }

  for (final decl in unit.decls) {
    blankBefore();
    switch (decl) {
      case StructDecl():
        _writeStruct(buf, decl, 0);
      case FuncDecl():
        _writeFunc(buf, decl, 0);
      default:
        throw StateError('unknown top-level declaration ${decl.runtimeType}');
    }
  }
  if (!buf.toString().endsWith('\n')) buf.writeln();
  return buf.toString();
}

void _writeAttrs(StringBuffer buf, List<Attr> attrs, int indent) {
  final pad = indentUnit * indent;
  for (final attr in attrs) {
    buf.write(pad);
    if (attr.arg != null) {
      buf.writeln('@[${attr.name}("${_escapeString(attr.arg!)}")]');
    } else {
      buf.writeln('@[${attr.name}]');
    }
  }
}

void _writeStruct(StringBuffer buf, StructDecl decl, int indent) {
  _writeAttrs(buf, decl.attrs, indent);
  final pad = indentUnit * indent;
  buf.write(pad);
  if (decl.isPub) buf.write('pub ');
  buf.writeln('struct ${decl.name} {');
  for (final field in decl.fields) {
    buf.writeln('$pad$indentUnit${field.name}: ${field.typeName}');
  }
  buf.writeln('$pad}');
}

void _writeFunc(StringBuffer buf, FuncDecl decl, int indent) {
  _writeAttrs(buf, decl.attrs, indent);
  final pad = indentUnit * indent;
  buf.write(pad);
  if (decl.isPub) buf.write('pub ');
  buf.write('fn ');
  final recv = decl.receiver;
  if (recv != null) {
    buf.write('(');
    if (recv.isMut) buf.write('mut ');
    buf.write('${recv.name}: ${recv.typeName}) ');
  }
  buf.write(decl.name);
  buf.write('(');
  buf.write(
    decl.params.map((p) => '${p.name}: ${p.typeName}').join(', '),
  );
  buf.write(')');
  if (decl.returnTypeName != null) {
    buf.write(': ${decl.returnTypeName}');
  }
  final body = decl.body;
  if (body == null) {
    buf.writeln();
    return;
  }
  buf.write(' ');
  _writeBlock(buf, body, indent, leadingNewline: false);
}

void _writeBlock(
  StringBuffer buf,
  Block block,
  int indent, {
  required bool leadingNewline,
}) {
  final pad = indentUnit * indent;
  if (leadingNewline) buf.write(pad);
  buf.writeln('{');
  for (final stmt in block.stmts) {
    _writeStmt(buf, stmt, indent + 1);
  }
  buf.writeln('$pad}');
}

void _writeStmt(StringBuffer buf, Stmt stmt, int indent) {
  final pad = indentUnit * indent;
  switch (stmt) {
    case AsmStmt(:final code):
      buf.writeln('${pad}asm("${_escapeString(code)}")');
    case LetStmt(
        :final isMut,
        :final name,
        :final typeName,
        :final init,
        :final shortDecl
      ):
      buf.write(pad);
      if (shortDecl) {
        buf.write('$name := ');
        buf.write(_expr(init!, indent));
        buf.writeln();
        break;
      }
      buf.write(isMut ? 'let mut ' : 'let ');
      buf.write(name);
      if (typeName != null) buf.write(': $typeName');
      if (init != null) {
        buf.write(' = ');
        buf.write(_expr(init, indent));
      }
      buf.writeln();
    case LetDestructureStmt(
        :final isMut,
        :final fields,
        :final binds,
        :final source
      ):
      buf.write(pad);
      buf.write(isMut ? 'let mut { ' : 'let { ');
      final parts = <String>[];
      for (var i = 0; i < fields.length; i++) {
        parts.add(fields[i] == binds[i] ? fields[i] : '${fields[i]}: ${binds[i]}');
      }
      buf.write(parts.join(', '));
      buf.write(' } = ');
      buf.write(_expr(source, indent));
      buf.writeln();
    case LetArrayDestructureStmt(:final isMut, :final names, :final source):
      buf.write(pad);
      buf.write(isMut ? 'let mut [' : 'let [');
      buf.write(names.map((n) => n ?? '_').join(', '));
      buf.write('] = ');
      buf.write(_expr(source, indent));
      buf.writeln();
    case AssignStmt(:final target, :final value):
      buf.writeln(
        '$pad${_expr(target, indent)} = ${_expr(value, indent)}',
      );
    case MultiAssignStmt(:final targets, :final values):
      final lhs = targets.map((t) => _expr(t, indent)).join(', ');
      final rhs = values.map((v) => _expr(v, indent)).join(', ');
      buf.writeln('$pad$lhs = $rhs');
    case StructAssignStmt(:final fields, :final targets, :final source):
      final parts = <String>[];
      for (var i = 0; i < fields.length; i++) {
        final target = targets[i];
        final plain = target is NameExpr && target.name == fields[i];
        parts.add(plain ? fields[i] : '${fields[i]}: ${_expr(target, indent)}');
      }
      buf.writeln('$pad{ ${parts.join(', ')} } = ${_expr(source, indent)}');
    case CallStmt(:final moduleName, :final callee, :final args):
      final name = moduleName == null ? callee : '$moduleName.$callee';
      buf.writeln('$pad$name(${_argList(args, indent)})');
    case MethodCallStmt(:final call):
      buf.writeln('$pad${_expr(call, indent)}');
    case IfStmt():
      _writeIf(buf, stmt, indent, chained: false);
    case WhileStmt(:final cond, :final body):
      buf.write('${pad}while ${_expr(cond, indent)} ');
      _writeBlock(buf, body, indent, leadingNewline: false);
    case ForRangeStmt(:final name, :final start, :final endExclusive, :final body):
      buf.write(
        '${pad}for $name in ${_expr(start, indent)}..<${_expr(endExclusive, indent)} ',
      );
      _writeBlock(buf, body, indent, leadingNewline: false);
    case ForCStmt(
        :final initName,
        :final initExpr,
        :final cond,
        :final postName,
        :final postExpr,
        :final body
      ):
      buf.write('${pad}for ');
      if (initName != null && initExpr != null) {
        buf.write('$initName = ${_expr(initExpr, indent)}');
      }
      buf.write('; ');
      if (cond != null) buf.write(_expr(cond, indent));
      buf.write('; ');
      if (postName != null && postExpr != null) {
        buf.write('$postName = ${_expr(postExpr, indent)}');
      }
      buf.write(' ');
      _writeBlock(buf, body, indent, leadingNewline: false);
    case ReturnStmt(:final value):
      if (value == null) {
        buf.writeln('${pad}return');
      } else {
        buf.writeln('${pad}return ${_expr(value, indent)}');
      }
    case BreakStmt():
      buf.writeln('${pad}break');
    case ContinueStmt():
      buf.writeln('${pad}continue');
    case DeferStmt(:final body):
      buf.write('${pad}defer ');
      if (body is BlockStmt) {
        _writeBlock(buf, body.block, indent, leadingNewline: false);
      } else {
        // Single deferred statement on the same line when possible.
        final inner = StringBuffer();
        _writeStmt(inner, body, 0);
        buf.write(inner.toString().trimRight());
        buf.writeln();
      }
    case BlockStmt(:final block):
      _writeBlock(buf, block, indent, leadingNewline: true);
    case MatchStmt(:final subject, :final arms):
      buf.write('${pad}match ${_expr(subject, indent)} {\n');
      for (final arm in arms) {
        buf.writeln('$pad$indentUnit${_patternText(arm.pattern, indent)} {');
        for (final s in arm.body.stmts) {
          _writeStmt(buf, s, indent + 2);
        }
        buf.writeln('$pad$indentUnit}');
      }
      buf.writeln('$pad}');
  }
}

String _patternText(MatchPattern pattern, int indent) {
  return switch (pattern) {
    LitPattern(:final values) =>
      values.map((v) => _expr(v, indent)).join(', '),
    RangePattern(:final start, :final endInclusive) =>
      '${_expr(start, indent)}..=${_expr(endInclusive, indent)}',
    ElsePattern() => 'else',
  };
}

void _writeIf(StringBuffer buf, IfStmt stmt, int indent, {required bool chained}) {
  final pad = indentUnit * indent;
  if (!chained) buf.write(pad);
  buf.write('if ${_expr(stmt.cond, indent)} {\n');
  for (final s in stmt.thenBlock.stmts) {
    _writeStmt(buf, s, indent + 1);
  }
  final elseBranch = stmt.elseBranch;
  if (elseBranch == null) {
    buf.writeln('$pad}');
    return;
  }
  buf.write('$pad} else ');
  if (elseBranch is IfStmt) {
    _writeIf(buf, elseBranch, indent, chained: true);
  } else if (elseBranch is BlockStmt) {
    buf.writeln('{');
    for (final s in elseBranch.block.stmts) {
      _writeStmt(buf, s, indent + 1);
    }
    buf.writeln('$pad}');
  } else {
    throw StateError('unexpected else branch ${elseBranch.runtimeType}');
  }
}

String _expr(Expr expr, [int indent = 0]) {
  return switch (expr) {
    IntLit(:final lexeme) => lexeme,
    FloatLit(:final lexeme) => lexeme,
    BoolLit(:final value) => value ? 'true' : 'false',
    StringLit(:final value) => '"${_escapeString(value)}"',
    InterpolatedStringExpr(:final parts) => () {
        final out = StringBuffer('"');
        for (final part in parts) {
          switch (part) {
            case InterpText(:final text):
              out.write(_escapeInterpText(text));
            case InterpSlot(:final expr, :final formatRaw):
              if (expr is NameExpr && formatRaw == null) {
                out.write('\$${expr.name}');
              } else if (formatRaw == null) {
                out.write('\${${_expr(expr, indent)}}');
              } else {
                out.write('\${${_expr(expr, indent)}:$formatRaw}');
              }
          }
        }
        out.write('"');
        return out.toString();
      }(),
    NameExpr(:final name) => name,
    FieldExpr(:final object, :final name) => '${_expr(object, indent)}.$name',
    MethodCallExpr(:final receiver, :final name, :final args) =>
      '${_expr(receiver, indent)}.$name(${_argList(args, indent)})',
    StructLitExpr(
      :final moduleName,
      :final typeName,
      :final namedFields,
      :final positionalFields
    ) =>
      () {
        final type =
            moduleName == null ? typeName : '$moduleName.$typeName';
        if (namedFields != null) {
          final fields = namedFields.entries
              .map((e) => '${e.key}: ${_expr(e.value, indent)}')
              .join(', ');
          return '$type{ $fields }';
        }
        final fields =
            positionalFields!.map((e) => _expr(e, indent)).join(', ');
        return fields.isEmpty ? '$type{}' : '$type{ $fields }';
      }(),
    CallExpr(:final moduleName, :final callee, :final args) => () {
        final name = moduleName == null ? callee : '$moduleName.$callee';
        return '$name(${_argList(args, indent)})';
      }(),
    UnaryExpr(:final op, :final operand) =>
      op == '*' || op == '&' || op == '-' || op == '!'
          ? '$op${_expr(operand, indent)}'
          : '$op(${_expr(operand, indent)})',
    IndexExpr(:final object, :final index) =>
      '${_expr(object, indent)}[${_expr(index, indent)}]',
    SliceFromExpr(:final array) => '${_expr(array, indent)}[:]',
    ArrayLitExpr(:final elements) =>
      '[${elements.map((e) => _expr(e, indent)).join(', ')}]',
    CastExpr(:final typeName, :final expr) =>
      'cast($typeName, ${_expr(expr, indent)})',
    BinaryExpr(:final left, :final op, :final right) =>
      '${_expr(left, indent)} $op ${_expr(right, indent)}',
    GroupExpr(:final inner) => '(${_expr(inner, indent)})',
    ErrorExpr(:final code) => 'error(${_expr(code, indent)})',
    PropagateExpr(:final result) => '${_expr(result, indent)}!',
    OrExpr(:final result, :final fallback) =>
      '${_expr(result, indent)} or ${_formatOrBlock(fallback, indent)}',
    MatchExpr(:final subject, :final arms) =>
      _formatMatchExpr(subject, arms, indent),
  };
}

String _formatMatchExpr(Expr subject, List<MatchExprArm> arms, int indent) {
  final pad = indentUnit * indent;
  final inner = indentUnit * (indent + 1);
  final buf = StringBuffer('match ${_expr(subject, indent)} {\n');
  for (final arm in arms) {
    buf.writeln(
      '$inner${_patternText(arm.pattern, indent + 1)} { ${_expr(arm.body, indent + 1)} }',
    );
  }
  buf.write('$pad}');
  return buf.toString();
}

String _formatOrBlock(OrBlock block, int indent) {
  final pad = indentUnit * indent;
  final inner = indentUnit * (indent + 1);
  if (block.stmts.isEmpty) {
    return '{ ${_expr(block.value, indent)} }';
  }
  final buf = StringBuffer('{\n');
  for (final stmt in block.stmts) {
    _writeStmt(buf, stmt, indent + 1);
  }
  buf.writeln('$inner${_expr(block.value, indent + 1)}');
  buf.write('$pad}');
  return buf.toString();
}

String _argList(List<Expr> args, [int indent = 0]) =>
    args.map((e) => _expr(e, indent)).join(', ');

String _escapeString(String value) {
  final buf = StringBuffer();
  for (final unit in value.codeUnits) {
    switch (unit) {
      case 0x5C: // \
        buf.write(r'\\');
      case 0x22: // "
        buf.write(r'\"');
      case 0x0A:
        buf.write(r'\n');
      case 0x0D:
        buf.write(r'\r');
      case 0x09:
        buf.write(r'\t');
      default:
        if (unit < 0x20) {
          buf.write('\\x${unit.toRadixString(16).padLeft(2, '0')}');
        } else {
          buf.writeCharCode(unit);
        }
    }
  }
  return buf.toString();
}

String _escapeInterpText(String value) {
  final buf = StringBuffer();
  for (final unit in value.codeUnits) {
    if (unit == 0x24) {
      // `$` — literal dollar inside interpolated string
      buf.write(r'\$');
      continue;
    }
    switch (unit) {
      case 0x5C:
        buf.write(r'\\');
      case 0x22:
        buf.write(r'\"');
      case 0x0A:
        buf.write(r'\n');
      case 0x0D:
        buf.write(r'\r');
      case 0x09:
        buf.write(r'\t');
      default:
        if (unit < 0x20) {
          buf.write('\\x${unit.toRadixString(16).padLeft(2, '0')}');
        } else {
          buf.writeCharCode(unit);
        }
    }
  }
  return buf.toString();
}
