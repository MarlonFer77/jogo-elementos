import 'dart:convert';

import 'package:app/game_domain/multiplayer_client.dart';
import 'package:app/game_domain/multiplayer_exception.dart';
import 'package:app/game_domain/multiplayer_match.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A tiny in-memory stand-in for the real backend (mirrors MatchStore's
/// behavior/contract closely enough to drive MultiplayerMatch end to end
/// without a real HTTP server). Both players share one instance through a
/// MockClient each, exactly like two browser tabs would share one real
/// server.
class _FakeBackend {
  final Map<String, Map<String, dynamic>> _matches = {};
  int _nextId = 1;

  http.Client asClient() => MockClient(_handle);

  Future<http.Response> _handle(http.Request request) async {
    final segments = request.url.pathSegments;
    if (request.method == 'POST' && segments.length == 1 && segments[0] == 'matches') {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final id = 'M${_nextId++}';
      final match = {
        'id': id,
        'playerAId': body['playerAId'],
        'playerBId': null,
        'status': 'waiting_for_opponent',
        'state': null,
      };
      _matches[id] = match;
      return http.Response(jsonEncode(match), 201);
    }

    if (request.method == 'POST' &&
        segments.length == 3 &&
        segments[0] == 'matches' &&
        segments[2] == 'join') {
      final match = _matches[segments[1]]!;
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      match['playerBId'] = body['playerBId'];
      match['status'] = 'in_progress';
      match['state'] = {
        'playerAId': match['playerAId'],
        'playerBId': match['playerBId'],
        'currentTurnId': match['playerAId'],
        'activeFieldEffects': <dynamic>[],
        'hp': <String, dynamic>{
          match['playerAId'] as String: {'max': 100, 'current': 100},
          match['playerBId'] as String: {'max': 100, 'current': 100},
        },
        'winner': null,
      };
      match['skillProgress'] = <String, dynamic>{
        match['playerAId'] as String: <String>[],
        match['playerBId'] as String: <String>[],
      };
      return http.Response(jsonEncode(match), 200);
    }

    if (request.method == 'POST' &&
        segments.length == 4 &&
        segments[0] == 'matches' &&
        segments[2] == 'skills' &&
        segments[3] == 'unlock') {
      final match = _matches[segments[1]]!;
      final state = match['state'] as Map<String, dynamic>?;
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final playerId = body['playerId'] as String;
      if (state == null || playerId != state['currentTurnId']) {
        return http.Response(jsonEncode({'error': 'not your turn'}), 400);
      }
      final skillProgress = match['skillProgress'] as Map<String, dynamic>;
      skillProgress[playerId] = [
        ...(skillProgress[playerId] as List).cast<String>(),
        body['nodeId'],
      ];
      return http.Response(jsonEncode({'match': match}), 200);
    }

    if (request.method == 'GET' && segments.length == 2 && segments[0] == 'matches') {
      return http.Response(jsonEncode(_matches[segments[1]]!), 200);
    }

    if (request.method == 'POST' &&
        segments.length == 3 &&
        segments[0] == 'matches' &&
        segments[2] == 'turns') {
      final match = _matches[segments[1]]!;
      final state = match['state'] as Map<String, dynamic>?;
      if (state == null) {
        return http.Response(jsonEncode({'error': 'not in progress'}), 409);
      }
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final actorId = body['actorId'] as String;
      if (actorId != state['currentTurnId']) {
        return http.Response(jsonEncode({'error': 'not your turn'}), 400);
      }

      final elementIds = (body['elementIds'] as List).cast<String>();
      // Only "fire"+"wind" is a known combination here, dealing 20 damage —
      // enough to drive a full match to a winner in this fake.
      final isCombo = elementIds.toSet().containsAll({'fire', 'wind'});
      String? triggeredCombinationId;
      if (isCombo) {
        final opponentId = actorId == match['playerAId']
            ? match['playerBId']
            : match['playerAId'];
        final hp = state['hp'] as Map<String, dynamic>;
        final pool = hp[opponentId] as Map<String, dynamic>;
        final nextCurrent = (pool['current'] as int) - 20;
        hp[opponentId] = {
          'max': pool['max'],
          'current': nextCurrent < 0 ? 0 : nextCurrent,
        };
        if (nextCurrent <= 0 && state['winner'] == null) {
          state['winner'] = actorId;
        }
        state['activeFieldEffects'] = [
          ...(state['activeFieldEffects'] as List),
          {'id': 'ignited_storm', 'area': 1, 'duration': null, 'damage': 20},
        ];
        triggeredCombinationId = 'ignited_storm';
      }
      state['currentTurnId'] = actorId == match['playerAId']
          ? match['playerBId']
          : match['playerAId'];
      if (state['winner'] != null) {
        match['status'] = 'finished';
      }

      return http.Response(
        jsonEncode({'match': match, 'triggeredCombinationId': triggeredCombinationId}),
        200,
      );
    }

    return http.Response(jsonEncode({'error': 'not found'}), 404);
  }
}

void main() {
  test('create leaves the match waiting for an opponent', () async {
    final backend = _FakeBackend();
    final match = MultiplayerMatch(
      client: MultiplayerClient(baseUrl: 'http://x', httpClient: backend.asClient()),
      localPlayerId: 'ana',
    );

    await match.create();

    expect(match.matchId, isNotNull);
    expect(match.isWaitingForOpponent, isTrue);
    expect(match.isInProgress, isFalse);
  });

  test('join starts the battle and exposes whose turn it is', () async {
    final backend = _FakeBackend();
    final host = MultiplayerMatch(
      client: MultiplayerClient(baseUrl: 'http://x', httpClient: backend.asClient()),
      localPlayerId: 'ana',
    );
    await host.create();

    final guest = MultiplayerMatch(
      client: MultiplayerClient(baseUrl: 'http://x', httpClient: backend.asClient()),
      localPlayerId: 'beto',
    );
    await guest.join(host.matchId!);

    expect(guest.isInProgress, isTrue);
    expect(guest.isMyTurn, isFalse); // ana (host) plays first
    expect(guest.opponentCurrentHp, 100);
    expect(guest.myCurrentHp, 100);
  });

  test('a full match: repeated combo damage decides a winner for both sides',
      () async {
    final backend = _FakeBackend();
    final ana = MultiplayerMatch(
      client: MultiplayerClient(baseUrl: 'http://x', httpClient: backend.asClient()),
      localPlayerId: 'ana',
    );
    await ana.create();
    final beto = MultiplayerMatch(
      client: MultiplayerClient(baseUrl: 'http://x', httpClient: backend.asClient()),
      localPlayerId: 'beto',
    );
    await beto.join(ana.matchId!);
    await ana.refresh();

    for (var i = 0; i < 4; i++) {
      await ana.playElementIds(['fire', 'wind']);
      await beto.refresh();
      await beto.playElementIds(['ice']);
      await ana.refresh();
    }
    await ana.playElementIds(['fire', 'wind']);
    await beto.refresh();

    expect(ana.isFinished, isTrue);
    expect(ana.amIWinner, isTrue);
    expect(beto.isFinished, isTrue);
    expect(beto.amIWinner, isFalse);
    expect(beto.opponentCurrentHp, 100);
    expect(beto.myCurrentHp, 0);
  });

  test('playElementIds surfaces the backend error and keeps the last state',
      () async {
    final backend = _FakeBackend();
    final ana = MultiplayerMatch(
      client: MultiplayerClient(baseUrl: 'http://x', httpClient: backend.asClient()),
      localPlayerId: 'ana',
    );
    await ana.create();
    final beto = MultiplayerMatch(
      client: MultiplayerClient(baseUrl: 'http://x', httpClient: backend.asClient()),
      localPlayerId: 'beto',
    );
    await beto.join(ana.matchId!);

    await expectLater(
      () => beto.playElementIds(['ice']),
      throwsA(isA<MultiplayerException>()),
    );
    expect(beto.lastError, isNotNull);
    expect(beto.isMyTurn, isFalse);
  });

  group('reconnect', () {
    test('re-fetches an existing match by id for a player already in it',
        () async {
      final backend = _FakeBackend();
      final ana = MultiplayerMatch(
        client: MultiplayerClient(baseUrl: 'http://x', httpClient: backend.asClient()),
        localPlayerId: 'ana',
      );
      await ana.create();
      final beto = MultiplayerMatch(
        client: MultiplayerClient(baseUrl: 'http://x', httpClient: backend.asClient()),
        localPlayerId: 'beto',
      );
      await beto.join(ana.matchId!);

      // A fresh MultiplayerMatch, as if the tab had been closed and
      // reopened — only localPlayerId + the shared code are known.
      final reconnectedBeto = MultiplayerMatch(
        client: MultiplayerClient(baseUrl: 'http://x', httpClient: backend.asClient()),
        localPlayerId: 'beto',
      );
      await reconnectedBeto.reconnect(ana.matchId!);

      expect(reconnectedBeto.isInProgress, isTrue);
      expect(reconnectedBeto.myCurrentHp, 100);
      expect(reconnectedBeto.opponentCurrentHp, 100);
    });

    test('throws when the local player is not part of that match', () async {
      final backend = _FakeBackend();
      final ana = MultiplayerMatch(
        client: MultiplayerClient(baseUrl: 'http://x', httpClient: backend.asClient()),
        localPlayerId: 'ana',
      );
      await ana.create();

      final stranger = MultiplayerMatch(
        client: MultiplayerClient(baseUrl: 'http://x', httpClient: backend.asClient()),
        localPlayerId: 'carla',
      );

      await expectLater(
        () => stranger.reconnect(ana.matchId!),
        throwsA(isA<MultiplayerException>()),
      );
      expect(stranger.matchId, isNull);
    });
  });

  group('startRematch', () {
    test('creates a fresh match for the same player, waiting for an opponent',
        () async {
      final backend = _FakeBackend();
      final ana = MultiplayerMatch(
        client: MultiplayerClient(baseUrl: 'http://x', httpClient: backend.asClient()),
        localPlayerId: 'ana',
      );
      await ana.create();
      final beto = MultiplayerMatch(
        client: MultiplayerClient(baseUrl: 'http://x', httpClient: backend.asClient()),
        localPlayerId: 'beto',
      );
      await beto.join(ana.matchId!);
      final firstMatchId = ana.matchId;

      final rematch = await ana.startRematch();

      expect(rematch.localPlayerId, 'ana');
      expect(rematch.matchId, isNotNull);
      expect(rematch.matchId, isNot(firstMatchId));
      expect(rematch.isWaitingForOpponent, isTrue);
      // The original match instance is untouched — it's still the
      // finished/in-progress one, not overwritten by the rematch.
      expect(ana.matchId, firstMatchId);
    });
  });

  group('unlockSkill', () {
    test('unlocking a node for the current-turn player updates unlockedNodeIdsForMe',
        () async {
      final backend = _FakeBackend();
      final ana = MultiplayerMatch(
        client: MultiplayerClient(baseUrl: 'http://x', httpClient: backend.asClient()),
        localPlayerId: 'ana',
      );
      await ana.create();
      final beto = MultiplayerMatch(
        client: MultiplayerClient(baseUrl: 'http://x', httpClient: backend.asClient()),
        localPlayerId: 'beto',
      );
      await beto.join(ana.matchId!);
      await ana.refresh();

      expect(ana.unlockedNodeIdsForMe, isEmpty);

      await ana.unlockSkill('ember_mastery');

      expect(ana.unlockedNodeIdsForMe, ['ember_mastery']);
      expect(beto.unlockedNodeIdsForMe, isEmpty);
    });

    test('throws when it is not the local player\'s turn', () async {
      final backend = _FakeBackend();
      final ana = MultiplayerMatch(
        client: MultiplayerClient(baseUrl: 'http://x', httpClient: backend.asClient()),
        localPlayerId: 'ana',
      );
      await ana.create();
      final beto = MultiplayerMatch(
        client: MultiplayerClient(baseUrl: 'http://x', httpClient: backend.asClient()),
        localPlayerId: 'beto',
      );
      await beto.join(ana.matchId!);

      await expectLater(
        () => beto.unlockSkill('ember_mastery'),
        throwsA(isA<MultiplayerException>()),
      );
      expect(beto.lastError, isNotNull);
    });
  });
}
