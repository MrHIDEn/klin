import 'ast.dart';

/// Emisja AST → jeden czytelny plik .c z dyrektywami `#line`.
String emitC(Program program, String sourcePath) {
  final buf = StringBuffer();
  buf.writeln('#include <stdio.h>');
  buf.writeln();
  _line(buf, program.pos.line, sourcePath);
  buf.writeln('int main(void) {');
  for (final call in program.body.calls) {
    _line(buf, call.pos.line, sourcePath);
    buf.writeln('    ${call.callee}("${_escapeC(call.argument)}");');
  }
  buf.writeln('    return 0;');
  buf.writeln('}');
  return buf.toString();
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
