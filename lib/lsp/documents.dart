/// In-memory overlay of open Klin documents (URI → source text).
final class DocumentStore {
  final Map<String, String> _docs = {};

  void open(String uri, String text) {
    _docs[uri] = text;
  }

  void change(String uri, String text) {
    _docs[uri] = text;
  }

  void close(String uri) {
    _docs.remove(uri);
  }

  String? get(String uri) => _docs[uri];

  bool contains(String uri) => _docs.containsKey(uri);
}
