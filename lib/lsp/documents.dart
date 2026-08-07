import 'package:klin/analyze.dart';

/// In-memory overlay of open Klin documents (URI → source + last analysis).
final class DocumentStore {
  final Map<String, String> _docs = {};
  final Map<String, AnalysisResult> _analysis = {};
  final Map<String, AnalysisResult> _lastGood = {};

  void open(String uri, String text) {
    _docs[uri] = text;
  }

  void change(String uri, String text) {
    _docs[uri] = text;
  }

  void close(String uri) {
    _docs.remove(uri);
    _analysis.remove(uri);
    _lastGood.remove(uri);
  }

  String? get(String uri) => _docs[uri];

  bool contains(String uri) => _docs.containsKey(uri);

  void setAnalysis(String uri, AnalysisResult result) {
    _analysis[uri] = result;
    if (result.program != null && !result.positionsSkewed) {
      _lastGood[uri] = result;
    }
  }

  AnalysisResult? analysis(String uri) => _analysis[uri];

  /// Last successful analysis for [uri] (for completion after `x.`).
  AnalysisResult? lastGood(String uri) => _lastGood[uri];
}
