// lib/src/html_stub.dart
// Stub for dart:html on non-web platforms.

/// Fake Blob so that HtmlBlob code compiles off-web:
class Blob {
  Blob(List<dynamic> chunks, String type);
}

/// Fake Url so that createObjectUrlFromBlob / revokeObjectUrl
/// compile off-web:
class Url {
  static String createObjectUrlFromBlob(Blob blob) => '';
  static void revokeObjectUrl(String url) {}
}