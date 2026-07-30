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
  _line(buf, program.pos.line, sourcePath);
  buf.writeln('int main(void) {');
  _emitBlock(buf, program.body, sourcePath, indent: 1);
  buf.writeln('    return 0;');
  buf.writeln('}');
  return buf.toString();
}

void _emitBlock(
  StringBuffer buf,
  Block block,
  String sourcePath, {
  required int indent,
}) {
  final pad = '    ' * indent;
  for (final stmt in block.stmts) {
    _emitStmt(buf, stmt, sourcePath, indent: indent, pad: pad);
  }
}

void _emitStmt(
  StringBuffer buf,
  Stmt stmt,
  String sourcePath, {
  required int indent,
  required String pad,
}) {
  switch (stmt) {
    case LetStmt(:final name, :final init, :final pos, :final resolvedType):
      _line(buf, pos.line, sourcePath);
      final ty = resolvedType;
      if (ty is! PrimType) {
        throw StateError('emit: brak typu dla `$name` — uruchom checker');
      }
      if (init != null) {
        buf.writeln('$pad${ty.kind.cType} $name = ${_emitExpr(init)};');
      } else {
        buf.writeln('$pad${ty.kind.cType} $name = ${ty.kind.cZero};');
      }

    case AssignStmt(:final name, :final value, :final pos):
      _line(buf, pos.line, sourcePath);
      buf.writeln('$pad$name = ${_emitExpr(value)};');

    case CallStmt(:final callee, :final args, :final pos):
      _line(buf, pos.line, sourcePath);
      final argList = args.map(_emitExpr).join(', ');
      buf.writeln('$pad$callee($argList);');

    case IfStmt(:final cond, :final thenBlock, :final elseBranch, :final pos):
      _line(buf, pos.line, sourcePath);
      buf.writeln('${pad}if (${_emitExpr(cond)}) {');
      _emitBlock(buf, thenBlock, sourcePath, indent: indent + 1);
      _emitElse(buf, elseBranch, sourcePath, indent: indent, pad: pad);

    case WhileStmt(:final cond, :final body, :final pos):
      _line(buf, pos.line, sourcePath);
      buf.writeln('${pad}while (${_emitExpr(cond)}) {');
      _emitBlock(buf, body, sourcePath, indent: indent + 1);
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
      _emitBlock(buf, body, sourcePath, indent: indent + 1);
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
      _emitBlock(buf, body, sourcePath, indent: indent + 1);
      buf.writeln('$pad}');

    case ReturnStmt(:final value, :final pos):
      _line(buf, pos.line, sourcePath);
      if (value == null) {
        buf.writeln('${pad}return 0;');
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
      _emitBlock(buf, block, sourcePath, indent: indent + 1);
      buf.writeln('$pad}');
  }
}

void _emitElse(
  StringBuffer buf,
  Stmt? elseBranch,
  String sourcePath, {
  required int indent,
  required String pad,
}) {
  if (elseBranch == null) {
    buf.writeln('$pad}');
    return;
  }
  if (elseBranch is IfStmt) {
    _line(buf, elseBranch.pos.line, sourcePath);
    buf.writeln('$pad} else if (${_emitExpr(elseBranch.cond)}) {');
    _emitBlock(buf, elseBranch.thenBlock, sourcePath, indent: indent + 1);
    _emitElse(
      buf,
      elseBranch.elseBranch,
      sourcePath,
      indent: indent,
      pad: pad,
    );
    return;
  }
  if (elseBranch is BlockStmt) {
    buf.writeln('$pad} else {');
    _emitBlock(buf, elseBranch.block, sourcePath, indent: indent + 1);
    buf.writeln('$pad}');
    return;
  }
  throw StateError('emit: nieoczekiwany else branch ${elseBranch.runtimeType}');
}

String _emitExpr(Expr expr) {
  return switch (expr) {
    IntLit(:final lexeme) => lexeme,
    FloatLit(:final lexeme) => lexeme,
    BoolLit(:final value) => value ? 'true' : 'false',
    StringLit(:final value) => '"${_escapeC(value)}"',
    NameExpr(:final name) => name,
    UnaryExpr(:final op, :final operand) => '$op(${_emitExpr(operand)})',
    BinaryExpr(:final left, :final op, :final right) =>
      '(${_emitExpr(left)} $op ${_emitExpr(right)})',
    GroupExpr(:final inner) => '(${_emitExpr(inner)})',
  };
}

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
