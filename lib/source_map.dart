import 'token.dart';

/// Maps positions between the editor buffer and preprocess-expanded text.
///
/// Built while expanding: each expanded offset points at an original offset.
/// Macro / SVD snippet insertions map to the call-site offset (synthetic).
final class SourceMap {
  /// `origOfExpanded[i]` = original UTF-16 offset for expanded offset `i`.
  final List<int> origOfExpanded;
  final String original;
  final String expanded;

  const SourceMap({
    required this.origOfExpanded,
    required this.original,
    required this.expanded,
  });

  /// Identity map when preprocess did not rewrite [source].
  factory SourceMap.identity(String source) {
    return SourceMap(
      origOfExpanded: [for (var i = 0; i < source.length; i++) i],
      original: source,
      expanded: source,
    );
  }

  bool get isIdentity => identical(original, expanded) || original == expanded;

  /// Map an expanded [pos] back to the editor buffer.
  SourcePos toOriginal(SourcePos pos) {
    if (origOfExpanded.isEmpty) return pos;
    final e = offsetOf(expanded, pos).clamp(0, origOfExpanded.length - 1);
    return positionOf(original, origOfExpanded[e]);
  }

  /// Map an editor [pos] into expanded space (for AST hit-tests).
  SourcePos toExpanded(SourcePos pos) {
    if (origOfExpanded.isEmpty) {
      return isIdentity ? pos : const SourcePos(1, 1);
    }
    final o = offsetOf(original, pos);

    // Exact original offset (identity char or call-site `$`).
    for (var i = 0; i < origOfExpanded.length; i++) {
      if (origOfExpanded[i] == o) return positionOf(expanded, i);
    }

    // Last expanded index whose original offset is <= [o].
    var best = -1;
    for (var i = 0; i < origOfExpanded.length; i++) {
      if (origOfExpanded[i] <= o) best = i;
    }
    if (best < 0) return positionOf(expanded, 0);

    final oo = origOfExpanded[best];
    var runStart = best;
    while (runStart > 0 && origOfExpanded[runStart - 1] == oo) {
      runStart--;
    }
    var runEnd = best;
    while (runEnd + 1 < origOfExpanded.length &&
        origOfExpanded[runEnd + 1] == oo) {
      runEnd++;
    }
    // Synthetic insertion: many expanded chars share the call-site offset.
    // Cursor inside the deleted `$name(…)` span (o > call site) must land in
    // the expansion, not on the identity text that follows.
    if (runEnd > runStart && o > oo) {
      return positionOf(expanded, runStart);
    }
    if (o > oo) {
      for (var i = best + 1; i < origOfExpanded.length; i++) {
        if (origOfExpanded[i] >= o) return positionOf(expanded, i);
      }
      return positionOf(expanded, expanded.length);
    }
    return positionOf(expanded, best);
  }
}

/// 0-based UTF-16 offset for a 1-based [pos] in [text].
int offsetOf(String text, SourcePos pos) {
  var offset = 0;
  var line = 1;
  while (line < pos.line && offset < text.length) {
    final next = text.indexOf('\n', offset);
    if (next < 0) return text.length;
    offset = next + 1;
    line++;
  }
  final lineEnd = text.indexOf('\n', offset);
  final maxCol = lineEnd < 0 ? text.length - offset : lineEnd - offset;
  final c = (pos.col - 1).clamp(0, maxCol);
  return offset + c;
}

/// 1-based [SourcePos] for a 0-based [offset] in [text].
SourcePos positionOf(String text, int offset) {
  final o = offset.clamp(0, text.length);
  var line = 1;
  var col = 1;
  for (var i = 0; i < o; i++) {
    if (text[i] == '\n') {
      line++;
      col = 1;
    } else {
      col++;
    }
  }
  return SourcePos(line, col);
}
