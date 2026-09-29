/// A multiplayer request failed — either the backend rejected it (e.g. not
/// your turn, match not found) or a network/parsing error occurred.
/// [statusCode] is null for the latter case.
class MultiplayerException implements Exception {
  final String message;
  final int? statusCode;
  final Duration? retryAfter;

  MultiplayerException(this.message, {this.statusCode, this.retryAfter});

  @override
  String toString() => message;
}
