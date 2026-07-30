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

    case CallStmt(:final callee, :final argument, :final pos):
      _line(buf, pos.line, sourcePath);
      buf.writeln('$pad$callee("${_escapeC(argument)}");');

    case BlockStmt(:final block):
      _line(buf, block.pos.line, sourcePath);
      buf.writeln('$pad{');
      _emitBlock(buf, block, sourcePath, indent: indent + 1);
      buf.writeln('$pad}');
  }
}

String _emitExpr(Expr expr) {
  return switch (expr) {
    IntLit(:final lexeme) => lexeme,
    FloatLit(:final lexeme) => lexeme,
    BoolLit(:final value) => value ? 'true' : 'false',
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
