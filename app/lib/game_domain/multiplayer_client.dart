import 'dart:convert';

import 'package:http/http.dart' as http;

import 'multiplayer_exception.dart';
import 'multiplayer_models.dart';

/// Thin HTTP client for the Multiplayer backend
/// (backend/src/routes/matches.ts) — one method per endpoint, JSON in, DTOs
/// out. No retries, no caching: callers (MultiplayerMatch) decide when to
/// call again.
class MultiplayerClient {
  MultiplayerClient({required this.baseUrl, http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _http;

  static const _jsonHeaders = {'Content-Type': 'application/json'};

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<RemoteMatch> createMatch(String playerAId) async {
    final response = await _http.post(
      _uri('/matches'),
      headers: _jsonHeaders,
      body: jsonEncode({'playerAId': playerAId}),
    );
    return RemoteMatch.fromJson(_decode(response));
  }

  Future<RemoteMatch> joinMatch(String matchId, String playerBId) async {
    final response = await _http.post(
      _uri('/matches/$matchId/join'),
      headers: _jsonHeaders,
      body: jsonEncode({'playerBId': playerBId}),
    );
    return RemoteMatch.fromJson(_decode(response));
  }

  Future<RemoteMatch> getMatch(String matchId) async {
    final response = await _http.get(_uri('/matches/$matchId'));
    return RemoteMatch.fromJson(_decode(response));
  }

  Future<SubmitTurnResult> submitTurn(
    String matchId, {
    required String actorId,
    required List<String> elementIds,
  }) async {
    final response = await _http.post(
      _uri('/matches/$matchId/turns'),
      headers: _jsonHeaders,
      body: jsonEncode({'actorId': actorId, 'elementIds': elementIds}),
    );
    final body = _decode(response);
    return SubmitTurnResult(
      match: RemoteMatch.fromJson(body['match'] as Map<String, dynamic>),
      triggeredCombinationId: body['triggeredCombinationId'] as String?,
    );
  }

  Future<RemoteMatch> unlockSkill(
    String matchId, {
    required String playerId,
    required String nodeId,
  }) async {
    final response = await _http.post(
      _uri('/matches/$matchId/skills/unlock'),
      headers: _jsonHeaders,
      body: jsonEncode({'playerId': playerId, 'nodeId': nodeId}),
    );
    final body = _decode(response);
    return RemoteMatch.fromJson(body['match'] as Map<String, dynamic>);
  }

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> body;
    try {
      body = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException {
      throw MultiplayerException(
        'resposta inválida do servidor',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MultiplayerException(
        body['error'] as String? ?? 'falha na requisição',
        statusCode: response.statusCode,
      );
    }
    return body;
  }
}
