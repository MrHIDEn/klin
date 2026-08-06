import 'package:klin/analyze.dart';

/// In-memory overlay of open Klin documents (URI → source + last analysis).
final class DocumentStore {
  final Map<String, String> _docs = {};
  final Map<String, AnalysisResult> _analysis = {};

  void open(String uri, String text) {
    _docs[uri] = text;
  }

  void change(String uri, String text) {
    _docs[uri] = text;
  }

  void close(String uri) {
    _docs.remove(uri);
    _analysis.remove(uri);
  }

  String? get(String uri) => _docs[uri];

  bool contains(String uri) => _docs.containsKey(uri);

  void setAnalysis(String uri, AnalysisResult result) {
    _analysis[uri] = result;
  }

  AnalysisResult? analysis(String uri) => _analysis[uri];
}
