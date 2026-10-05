import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:http/http.dart' as http;

import 'multiplayer_exception.dart';
import 'multiplayer_models.dart';

/// Thin HTTP client for the Multiplayer backend
/// (backend/src/routes/matches.ts) — one method per endpoint, JSON in, DTOs
/// out. No retries, no caching: callers (MultiplayerMatch) decide when to
/// call again.
class MultiplayerClient {
  MultiplayerClient({
    required this.baseUrl,
    http.Client? httpClient,
    this.idToken,
    this.accountId,
  }) : _http = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _http;
  final Future<String> Function()? idToken;
  final String? accountId;
  String get _sessionScope =>
      accountId == null ? baseUrl : '$baseUrl.account.$accountId';

  Future<Map<String, String>>? _sessionHeaders;
  Future<Map<String, String>> _headers() async => idToken != null
      ? {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await idToken!()}',
        }
      : await (_sessionHeaders ??= _loadHeaders());

  Future<String?> legacyToken() async => (await SharedPreferences.getInstance())
      .getString('multiplayer.session.$baseUrl');

  Future<String> account({
    String? playerId,
    String? legacyToken,
    String? matchId,
  }) async {
    final response = playerId == null
        ? await _http
              .get(_uri('/account'), headers: await _headers())
              .timeout(const Duration(seconds: 20))
        : await _http
              .post(
                _uri('/account'),
                headers: await _headers(),
                body: jsonEncode({
                  'playerId': playerId,
                  'legacyToken': ?legacyToken,
                  'matchId': ?matchId,
                }),
              )
              .timeout(const Duration(seconds: 20));
    return _decode(response)['playerId'] as String;
  }

  Future<Map<String, String>> _loadHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'multiplayer.session.$baseUrl';
    var token = prefs.getString(key);
    if (token == null) {
      final random = Random.secure();
      token = List.generate(
        32,
        (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      if (!await prefs.setString(key, token)) {
        throw StateError('Não foi possível salvar a sessão multiplayer.');
      }
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  /// Wake the free server with a read-only request before any room action.
  /// No retries: a timed-out POST must never be replayed automatically.
  Future<void> waitUntilReady({bool requireAccount = false}) async {
    final response = await _http
        .get(_uri('/health'))
        .timeout(const Duration(seconds: 60));
    final health = _decode(response);
    if (requireAccount && health['accounts'] != true) {
      throw MultiplayerException(
        'O servidor ainda não recebeu o login. Atualize o backend antes de usar esta versão.',
      );
    }
    if (health['status'] != 'ok' || health['protocol'] != 2) {
      throw MultiplayerException(
        'Servidor incompatível ou ainda indisponível. Tente novamente mais tarde.',
      );
    }
  }

  Future<void> rememberSession(String id, String player) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('multiplayer.lastCode.$_sessionScope', id);
    await prefs.setString('multiplayer.lastPlayer.$_sessionScope', player);
  }

  Future<(String, String)> lastSession() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      prefs.getString('multiplayer.lastPlayer.$_sessionScope') ?? '',
      prefs.getString('multiplayer.lastCode.$_sessionScope') ?? '',
    );
  }

  Future<RemoteMatch> createMatch(String playerAId) async {
    final response = await _http
        .post(
          _uri('/matches'),
          headers: await _headers(),
          body: jsonEncode({'playerAId': playerAId}),
        )
        .timeout(const Duration(seconds: 20));
    final match = RemoteMatch.fromJson(_decode(response));
    await rememberSession(match.id, playerAId);
    return match;
  }

  Future<RemoteMatch> joinMatch(String matchId, String playerBId) async {
    final response = await _http
        .post(
          _uri('/matches/$matchId/join'),
          headers: await _headers(),
          body: jsonEncode({'playerBId': playerBId}),
        )
        .timeout(const Duration(seconds: 20));
    final match = RemoteMatch.fromJson(_decode(response));
    await rememberSession(match.id, playerBId);
    return match;
  }

  Future<RemoteMatch> getMatch(String matchId) async {
    final response = await _http
        .get(_uri('/matches/$matchId'), headers: await _headers())
        .timeout(const Duration(seconds: 20));
    return RemoteMatch.fromJson(_decode(response));
  }

  Future<RemoteMatch> seal(
    String id,
    Map<String, dynamic> body, {
    bool finish = false,
  }) async {
    final response = await _http
        .post(
          _uri('/matches/$id/seal/${finish ? 'finish' : 'start'}'),
          headers: await _headers(),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 20));
    return RemoteMatch.fromJson(_decode(response));
  }

  Future<RemoteMatch> surrender(String id, String playerId) async {
    final response = await _http
        .post(
          _uri('/matches/$id/surrender'),
          headers: await _headers(),
          body: jsonEncode({'playerId': playerId}),
        )
        .timeout(const Duration(seconds: 20));
    return RemoteMatch.fromJson(_decode(response));
  }

  Future<SubmitTurnResult> submitTurn(
    String matchId, {
    required String actorId,
    required List<String> elementIds,
    bool defending = false,
    bool thawing = false,
    bool preview = false,
    int revision = 0,
  }) async {
    final response = await _http
        .post(
          _uri('/matches/$matchId/${preview ? 'preview' : 'turns'}'),
          headers: await _headers(),
          body: jsonEncode({
            'actorId': actorId,
            'revision': revision,
            'elementIds': elementIds,
            if (defending || thawing) 'kind': thawing ? 'thaw' : 'defend',
          }),
        )
        .timeout(const Duration(seconds: 20));
    final body = _decode(response);
    return SubmitTurnResult(
      match: RemoteMatch.fromJson(body['match'] as Map<String, dynamic>),
      triggeredCombinationId: body['triggeredCombinationId'] as String?,
      beforeState: preview
          ? RemoteBattleState.fromJson(
              body['beforeState'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  Future<RemoteMatch> unlockSkill(
    String matchId, {
    required String playerId,
    required String nodeId,
    int revision = 0,
  }) async {
    final response = await _http
        .post(
          _uri('/matches/$matchId/skills/unlock'),
          headers: await _headers(),
          body: jsonEncode({
            'playerId': playerId,
            'nodeId': nodeId,
            'revision': revision,
          }),
        )
        .timeout(const Duration(seconds: 20));
    final body = _decode(response);
    return RemoteMatch.fromJson(body['match'] as Map<String, dynamic>);
  }

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> body;
    try {
      final decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Objeto JSON esperado.');
      }
      body = decoded;
    } on FormatException {
      throw MultiplayerException(
        'resposta inválida do servidor',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final retrySeconds = int.tryParse(response.headers['retry-after'] ?? '');
      throw MultiplayerException(
        body['error'] as String? ?? 'falha na requisição',
        statusCode: response.statusCode,
        retryAfter: retrySeconds == null
            ? null
            : Duration(seconds: retrySeconds.clamp(1, 600)),
      );
    }
    final match =
        body['match'] ?? (body.containsKey('playerAId') ? body : null);
    if (match is Map &&
        (match['revision'] is! int || match['players'] is! Map)) {
      throw MultiplayerException(
        'Backend incompatível. Atualize o servidor junto com este aplicativo.',
      );
    }
    return body;
  }

  Future<RemoteMatch> configure(
    String matchId,
    String playerId,
    String kind,
    List<String> ids,
    int revision,
  ) async {
    final response = await _http
        .post(
          _uri('/matches/$matchId/configure'),
          headers: await _headers(),
          body: jsonEncode({
            'playerId': playerId,
            'kind': kind,
            'ids': ids,
            'revision': revision,
          }),
        )
        .timeout(const Duration(seconds: 20));
    return RemoteMatch.fromJson(_decode(response));
  }
}
