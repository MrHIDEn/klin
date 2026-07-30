import 'ast.dart';
import 'type.dart';

/// Emisja AST → jeden czytelny plik .c z dyrektywami `#line`.
String emitC(Program program, String sourcePath) {
  final buf = StringBuffer();
  buf.writeln('#include <stdio.h>');
  buf.writeln('#include <stdint.h>');
  buf.writeln('#include <stddef.h>');
  buf.writeln('#include <stdbool.h>');
  buf.writeln();
  for (final struct in program.structs) {
    _line(buf, struct.pos.line, struct.sourcePath ?? sourcePath);
    buf.writeln('typedef struct {');
    for (final field in struct.fields) {
      final type = field.resolvedType;
      if (type == null)
        throw StateError('emit: brak typu pola `${field.name}`');
      buf.writeln('    ${_cType(type)} ${field.name};');
    }
    buf.writeln('} ${_structCName(struct.moduleName, struct.name)};');
    buf.writeln();
  }
  for (final func in program.funcs) {
    buf.writeln('${_functionHeader(func)};');
  }
  buf.writeln();
  for (final func in program.funcs) {
    _line(buf, func.pos.line, func.sourcePath ?? sourcePath);
    buf.writeln('${_functionHeader(func)} {');
    _emitBlock(
      buf,
      func.body,
      func.sourcePath ?? sourcePath,
      indent: 1,
      bareReturnAsZero: func.name == 'main',
    );
    if (func.name == 'main') buf.writeln('    return 0;');
    buf.writeln('}');
    buf.writeln();
  }
  return buf.toString();
}

String _functionHeader(FuncDecl func) {
  if (func.name == 'main') return 'int main(void)';
  final returnType = func.resolvedReturnType;
  if (returnType == null) {
    throw StateError('emit: brak typu zwracanego funkcji `${func.name}`');
  }
  final params = <String>[
    if (func.receiver case final receiver?)
      '${_cType(receiver.resolvedType!)}${receiver.isMut ? ' *' : ' '}${receiver.name}',
    ...func.params.map((param) {
      final type = param.resolvedType;
      if (type == null) {
        throw StateError('emit: brak typu parametru `${param.name}`');
      }
      return '${_cType(type)} ${param.name}';
    }),
  ];
  final name = func.name == 'main'
      ? 'main'
      : func.receiver == null
          ? '${func.moduleName}_${func.name}'
          : '${func.moduleName}_${_receiverTypeName(func.receiver!)}_${func.name}';
  final staticPrefix = !func.isPub && func.name != 'main' ? 'static ' : '';
  return '$staticPrefix${_cType(returnType)} $name(${params.isEmpty ? 'void' : params.join(', ')})';
}

String _receiverTypeName(Receiver receiver) => receiver.typeName.contains('.')
    ? receiver.typeName.split('.').last
    : receiver.typeName;

String _cType(KlinType type) => switch (type) {
      PrimType(:final kind) => kind.cType,
      VoidType() => 'void',
      StrType() => 'const char*',
      StructType(:final moduleName, :final name) =>
        _structCName(moduleName, name),
      _ => throw StateError('emit: typ `${type.displayName}` nie ma typu C'),
    };

void _emitBlock(
  StringBuffer buf,
  Block block,
  String sourcePath, {
  required int indent,
  required bool bareReturnAsZero,
}) {
  final pad = '    ' * indent;
  for (final stmt in block.stmts) {
    _emitStmt(
      buf,
      stmt,
      sourcePath,
      indent: indent,
      pad: pad,
      bareReturnAsZero: bareReturnAsZero,
    );
  }
}

void _emitStmt(
  StringBuffer buf,
  Stmt stmt,
  String sourcePath, {
  required int indent,
  required String pad,
  required bool bareReturnAsZero,
}) {
  switch (stmt) {
    case LetStmt(:final name, :final init, :final pos, :final resolvedType):
      _line(buf, pos.line, sourcePath);
      final ty = resolvedType;
      if (ty == null ||
          (ty is! PrimType && ty is! StrType && ty is! StructType)) {
        throw StateError('emit: brak typu dla `$name` — uruchom checker');
      }
      if (init != null) {
        buf.writeln('$pad${_cType(ty)} $name = ${_emitExpr(init)};');
      } else {
        if (ty is! PrimType) {
          throw StateError('emit: brak wartości domyślnej dla `$name`');
        }
        buf.writeln('$pad${ty.kind.cType} $name = ${ty.kind.cZero};');
      }

    case AssignStmt(:final target, :final value, :final pos):
      _line(buf, pos.line, sourcePath);
      buf.writeln('$pad${_emitExpr(target)} = ${_emitExpr(value)};');

    case CallStmt(
        :final callee,
        :final args,
        :final pos,
        :final resolvedCallee
      ):
      _line(buf, pos.line, sourcePath);
      final argList = args.map(_emitExpr).join(', ');
      buf.writeln('$pad${resolvedCallee ?? callee}($argList);');

    case MethodCallStmt(:final call):
      _line(buf, call.pos.line, sourcePath);
      buf.writeln('$pad${_emitExpr(call)};');

    case IfStmt(:final cond, :final thenBlock, :final elseBranch, :final pos):
      _line(buf, pos.line, sourcePath);
      buf.writeln('${pad}if (${_emitExpr(cond)}) {');
      _emitBlock(
        buf,
        thenBlock,
        sourcePath,
        indent: indent + 1,
        bareReturnAsZero: bareReturnAsZero,
      );
      _emitElse(
        buf,
        elseBranch,
        sourcePath,
        indent: indent,
        pad: pad,
        bareReturnAsZero: bareReturnAsZero,
      );

    case WhileStmt(:final cond, :final body, :final pos):
      _line(buf, pos.line, sourcePath);
      buf.writeln('${pad}while (${_emitExpr(cond)}) {');
      _emitBlock(
        buf,
        body,
        sourcePath,
        indent: indent + 1,
        bareReturnAsZero: bareReturnAsZero,
      );
      buf.writeln('$pad}');

    case ForRangeStmt(
        :final name,
        :final start,
        :final endExclusive,
        :final body,
        :final pos,
        :final resolvedType
      ):
      _line(buf, pos.line, sourcePath);
      final ty = resolvedType;
      if (ty is! PrimType) {
        throw StateError('emit: brak typu dla zmiennej pętli `$name`');
      }
      buf.writeln(
        '${pad}for (${ty.kind.cType} $name = ${_emitExpr(start)}; '
        '$name < ${_emitExpr(endExclusive)}; $name++) {',
      );
      _emitBlock(
        buf,
        body,
        sourcePath,
        indent: indent + 1,
        bareReturnAsZero: bareReturnAsZero,
      );
      buf.writeln('$pad}');

    case ForCStmt(
        :final initName,
        :final initExpr,
        :final cond,
        :final postName,
        :final postExpr,
        :final body,
        :final pos,
        :final resolvedInitType
      ):
      _line(buf, pos.line, sourcePath);
      final initPart = () {
        if (initName == null || initExpr == null) return '';
        final ty = resolvedInitType;
        if (ty is! PrimType) {
          throw StateError('emit: brak typu dla init `$initName`');
        }
        return '${ty.kind.cType} $initName = ${_emitExpr(initExpr)}';
      }();
      final condPart = cond == null ? '' : _emitExpr(cond);
      final postPart = (postName != null && postExpr != null)
          ? '$postName = ${_emitExpr(postExpr)}'
          : '';
      buf.writeln('${pad}for ($initPart; $condPart; $postPart) {');
      _emitBlock(
        buf,
        body,
        sourcePath,
        indent: indent + 1,
        bareReturnAsZero: bareReturnAsZero,
      );
      buf.writeln('$pad}');

    case ReturnStmt(:final value, :final pos):
      _line(buf, pos.line, sourcePath);
      if (value == null) {
        buf.writeln(bareReturnAsZero ? '${pad}return 0;' : '${pad}return;');
      } else {
        buf.writeln('${pad}return ${_emitExpr(value)};');
      }

    case BreakStmt(:final pos):
      _line(buf, pos.line, sourcePath);
      buf.writeln('${pad}break;');

    case ContinueStmt(:final pos):
      _line(buf, pos.line, sourcePath);
      buf.writeln('${pad}continue;');

    case BlockStmt(:final block):
      _line(buf, block.pos.line, sourcePath);
      buf.writeln('$pad{');
      _emitBlock(
        buf,
        block,
        sourcePath,
        indent: indent + 1,
        bareReturnAsZero: bareReturnAsZero,
      );
      buf.writeln('$pad}');
  }
}

void _emitElse(
  StringBuffer buf,
  Stmt? elseBranch,
  String sourcePath, {
  required int indent,
  required String pad,
  required bool bareReturnAsZero,
}) {
  if (elseBranch == null) {
    buf.writeln('$pad}');
    return;
  }
  if (elseBranch is IfStmt) {
    _line(buf, elseBranch.pos.line, sourcePath);
    buf.writeln('$pad} else if (${_emitExpr(elseBranch.cond)}) {');
    _emitBlock(
      buf,
      elseBranch.thenBlock,
      sourcePath,
      indent: indent + 1,
      bareReturnAsZero: bareReturnAsZero,
    );
    _emitElse(
      buf,
      elseBranch.elseBranch,
      sourcePath,
      indent: indent,
      pad: pad,
      bareReturnAsZero: bareReturnAsZero,
    );
    return;
  }
  if (elseBranch is BlockStmt) {
    buf.writeln('$pad} else {');
    _emitBlock(
      buf,
      elseBranch.block,
      sourcePath,
      indent: indent + 1,
      bareReturnAsZero: bareReturnAsZero,
    );
    buf.writeln('$pad}');
    return;
  }
  throw StateError('emit: nieoczekiwany else branch ${elseBranch.runtimeType}');
}

bool _exprIsPtrReceiver(Expr expr) {
  var current = expr;
  while (current is GroupExpr) {
    current = current.inner;
  }
  return current is NameExpr && current.isPtrReceiver;
}

String _emitExpr(Expr expr) {
  return switch (expr) {
    IntLit(:final lexeme) => lexeme,
    FloatLit(:final lexeme) => lexeme,
    BoolLit(:final value) => value ? 'true' : 'false',
    StringLit(:final value) => '"${_escapeC(value)}"',
    NameExpr(:final name) => name,
    FieldExpr(:final object, :final name) => _exprIsPtrReceiver(object)
        ? '${_emitExpr(object)}->$name'
        : '${_emitExpr(object)}.$name',
    MethodCallExpr(
      :final receiver,
      :final args,
      :final mangledName,
      :final receiverByRef,
    ) =>
      '${mangledName ?? (throw StateError('emit: metoda bez manglingu'))}'
          '(${receiverByRef ? '&' : ''}${_emitExpr(receiver)}'
          '${args.isEmpty ? '' : ', ${args.map(_emitExpr).join(', ')}'})',
    StructLitExpr(
      :final resolvedType,
      :final typeName,
      :final namedFields,
      :final positionalFields
    ) =>
      namedFields != null
          ? '(${_cType(resolvedType ?? (throw StateError('emit: literał bez typu `$typeName`')))}){ ${namedFields.entries.map((entry) => '.${entry.key} = ${_emitExpr(entry.value)}').join(', ')} }'
          : '(${_cType(resolvedType ?? (throw StateError('emit: literał bez typu `$typeName`')))}){ ${positionalFields!.map(_emitExpr).join(', ')} }',
    CallExpr(:final callee, :final args, :final resolvedCallee) =>
      '${resolvedCallee ?? callee}(${args.map(_emitExpr).join(', ')})',
    UnaryExpr(:final op, :final operand) => '$op(${_emitExpr(operand)})',
    BinaryExpr(:final left, :final op, :final right) =>
      '(${_emitExpr(left)} $op ${_emitExpr(right)})',
    GroupExpr(:final inner) => '(${_emitExpr(inner)})',
  };
}

String _structCName(String module, String name) =>
    module.isEmpty ? name : '${module}_$name';

void _line(StringBuffer buf, int line, String path) {
  buf.writeln('#line $line "${_escapeC(path)}"');
}

String _escapeC(String s) {
  final out = StringBuffer();
  for (final cu in s.runes) {
    switch (cu) {
      case 0x0A: // \n
        out.write('\\n');
      case 0x09: // \t
        out.write('\\t');
      case 0x22: // "
        out.write('\\"');
      case 0x5C: // \
        out.write('\\\\');
      default:
        if (cu < 0x20 || cu == 0x7F) {
          out.write('\\x${cu.toRadixString(16).padLeft(2, '0')}');
        } else {
          out.writeCharCode(cu);
        }
    }
  }
  return out.toString();
}
