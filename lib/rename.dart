import 'analyze.dart';
import 'ast.dart';
import 'navigate.dart';
import 'token.dart';

final class KlinTextEdit {
  final String path;
  final SourcePos pos;
  final int length;
  final String newText;

  const KlinTextEdit({
    required this.path,
    required this.pos,
    required this.length,
    required this.newText,
  });
}

bool _isIdent(String name) {
  if (name.isEmpty) return false;
  final c0 = name.codeUnitAt(0);
  final startOk = (c0 >= 97 && c0 <= 122) ||
      (c0 >= 65 && c0 <= 90) ||
      c0 == 95;
  if (!startOk) return false;
  for (var i = 1; i < name.length; i++) {
    final c = name.codeUnitAt(i);
    if (!((c >= 97 && c <= 122) ||
        (c >= 65 && c <= 90) ||
        (c >= 48 && c <= 57) ||
        c == 95)) {
      return false;
    }
  }
  return true;
}

/// Range of the renameable name at editor [line]/[col], or null.
({SourcePos pos, int length, String placeholder})? prepareRenameAt(
  AnalysisResult result,
  int line,
  int col, {
  String? openPath,
}) {
  if (result.positionsSkewed || result.program == null) return null;
  final map = result.sourceMap;
  final q = map?.toExpanded(SourcePos(line, col)) ?? SourcePos(line, col);
  final target = findNavTarget(result.program!, q.line, q.col);
  if (target == null || target.def == null) return null;
  final editorPos = _toEditorPos(target.pos, target.def?.path, map, openPath);
  return (
    pos: editorPos,
    length: target.nameLength,
    placeholder: target.label,
  );
}

/// Workspace text edits renaming the symbol at [line]/[col] to [newName].
///
/// Covers the open file (with [SourceMap] remapping) and other files present
/// in the analyzed [Program] (cross-file when loaded via `loadProject`).
List<KlinTextEdit>? renameAt(
  AnalysisResult result,
  int line,
  int col,
  String newName, {
  required String openPath,
}) {
  if (!_isIdent(newName)) return null;
  if (result.positionsSkewed || result.program == null) return null;
  final map = result.sourceMap;
  final q = map?.toExpanded(SourcePos(line, col)) ?? SourcePos(line, col);
  final target = findNavTarget(result.program!, q.line, q.col);
  final def = target?.def;
  if (def == null) return null;

  final edits = <KlinTextEdit>[];
  final seen = <String>{};
  for (final t in allNavTargets(result.program!)) {
    if (!sameResolvedDef(t.def, def)) continue;
    final path = t.def?.path ?? openPath;
    final editorPos = _toEditorPos(t.pos, path, map, openPath);
    final key = '$path:${editorPos.line}:${editorPos.col}:${t.nameLength}';
    if (!seen.add(key)) continue;
    edits.add(
      KlinTextEdit(
        path: path.isEmpty ? openPath : path,
        pos: editorPos,
        length: t.nameLength,
        newText: newName,
      ),
    );
  }
  if (edits.isEmpty) return null;
  edits.sort((a, b) {
    final pc = a.path.compareTo(b.path);
    if (pc != 0) return pc;
    if (a.pos.line != b.pos.line) return a.pos.line.compareTo(b.pos.line);
    return a.pos.col.compareTo(b.pos.col);
  });
  return edits;
}

SourcePos _toEditorPos(
  SourcePos expandedPos,
  String? defPath,
  SourceMap? map,
  String? openPath,
) {
  if (map == null || openPath == null) return expandedPos;
  final path = defPath ?? openPath;
  if (!sameDiagnosticPath(path, openPath)) return expandedPos;
  return map.toOriginal(expandedPos);
}
