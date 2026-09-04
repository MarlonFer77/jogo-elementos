import 'dart:convert';

import 'package:app/game_domain/multiplayer_client.dart';
import 'package:app/game_domain/multiplayer_exception.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('createMatch', () {
    test('posts playerAId and parses the created match', () async {
      late http.Request captured;
      final client = MultiplayerClient(
        baseUrl: 'http://localhost:3000',
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'id': 'ABC123',
              'playerAId': 'ana',
              'playerBId': null,
              'status': 'waiting_for_opponent',
              'state': null,
            }),
            201,
          );
        }),
      );

      final match = await client.createMatch('ana');

      expect(captured.method, 'POST');
      expect(captured.url.toString(), 'http://localhost:3000/matches');
      expect(jsonDecode(captured.body), {'playerAId': 'ana'});
      expect(match.id, 'ABC123');
      expect(match.playerAId, 'ana');
      expect(match.playerBId, null);
      expect(match.status, 'waiting_for_opponent');
      expect(match.state, null);
      expect(match.skillProgress, <String, List<String>>{});
    });
  });

  group('joinMatch', () {
    test('posts playerBId and parses the in-progress match with state',
        () async {
      late http.Request captured;
      final client = MultiplayerClient(
        baseUrl: 'http://localhost:3000',
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'id': 'ABC123',
              'playerAId': 'ana',
              'playerBId': 'beto',
              'status': 'in_progress',
              'state': {
                'playerAId': 'ana',
                'playerBId': 'beto',
                'currentTurnId': 'ana',
                'activeFieldEffects': [],
                'hp': {
                  'ana': {'max': 100, 'current': 100},
                  'beto': {'max': 100, 'current': 100},
                },
                'winner': null,
              },
            }),
            200,
          );
        }),
      );

      final match = await client.joinMatch('ABC123', 'beto');

      expect(captured.method, 'POST');
      expect(
        captured.url.toString(),
        'http://localhost:3000/matches/ABC123/join',
      );
      expect(jsonDecode(captured.body), {'playerBId': 'beto'});
      expect(match.status, 'in_progress');
      expect(match.state?.currentTurnId, 'ana');
      expect(match.state?.hp['beto']?.current, 100);
    });
  });

  group('getMatch', () {
    test('gets the match by id', () async {
      late http.Request captured;
      final client = MultiplayerClient(
        baseUrl: 'http://localhost:3000',
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'id': 'ABC123',
              'playerAId': 'ana',
              'playerBId': null,
              'status': 'waiting_for_opponent',
              'state': null,
            }),
            200,
          );
        }),
      );

      final match = await client.getMatch('ABC123');

      expect(captured.method, 'GET');
      expect(
        captured.url.toString(),
        'http://localhost:3000/matches/ABC123',
      );
      expect(match.id, 'ABC123');
    });
  });

  group('submitTurn', () {
    test('posts actorId/elementIds and parses match + triggeredCombinationId',
        () async {
      late http.Request captured;
      final client = MultiplayerClient(
        baseUrl: 'http://localhost:3000',
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'match': {
                'id': 'ABC123',
                'playerAId': 'ana',
                'playerBId': 'beto',
                'status': 'in_progress',
                'state': {
                  'playerAId': 'ana',
                  'playerBId': 'beto',
                  'currentTurnId': 'beto',
                  'activeFieldEffects': [
                    {
                      'id': 'ignited_storm',
                      'area': 1,
                      'duration': null,
                      'damage': 20,
                    },
                  ],
                  'hp': {
                    'ana': {'max': 100, 'current': 100},
                    'beto': {'max': 100, 'current': 80},
                  },
                  'winner': null,
                },
              },
              'triggeredCombinationId': 'ignited_storm',
            }),
            200,
          );
        }),
      );

      final result = await client.submitTurn(
        'ABC123',
        actorId: 'ana',
        elementIds: ['fire', 'wind'],
      );

      expect(captured.method, 'POST');
      expect(
        captured.url.toString(),
        'http://localhost:3000/matches/ABC123/turns',
      );
      expect(jsonDecode(captured.body), {
        'actorId': 'ana',
        'elementIds': ['fire', 'wind'],
      });
      expect(result.triggeredCombinationId, 'ignited_storm');
      expect(result.match.state?.hp['beto']?.current, 80);
      expect(result.match.state?.activeFieldEffects.single.damage, 20);
    });
  });

  group('unlockSkill', () {
    test('posts playerId/nodeId and parses the updated match', () async {
      late http.Request captured;
      final client = MultiplayerClient(
        baseUrl: 'http://localhost:3000',
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'match': {
                'id': 'ABC123',
                'playerAId': 'ana',
                'playerBId': 'beto',
                'status': 'in_progress',
                'state': {
                  'playerAId': 'ana',
                  'playerBId': 'beto',
                  'currentTurnId': 'ana',
                  'activeFieldEffects': [],
                  'hp': {
                    'ana': {'max': 100, 'current': 100},
                    'beto': {'max': 100, 'current': 100},
                  },
                  'winner': null,
                },
                'skillProgress': {
                  'ana': ['ember_mastery'],
                  'beto': [],
                },
              },
            }),
            200,
          );
        }),
      );

      final match = await client.unlockSkill(
        'ABC123',
        playerId: 'ana',
        nodeId: 'ember_mastery',
      );

      expect(captured.method, 'POST');
      expect(
        captured.url.toString(),
        'http://localhost:3000/matches/ABC123/skills/unlock',
      );
      expect(jsonDecode(captured.body), {
        'playerId': 'ana',
        'nodeId': 'ember_mastery',
      });
      expect(match.skillProgress['ana'], ['ember_mastery']);
      expect(match.skillProgress['beto'], <String>[]);
    });
  });

  group('error handling', () {
    test('throws MultiplayerException with the backend message and status',
        () async {
      final client = MultiplayerClient(
        baseUrl: 'http://localhost:3000',
        httpClient: MockClient((request) async {
          return http.Response(
            jsonEncode({'error': 'match "GHOST1" not found'}),
            404,
          );
        }),
      );

      await expectLater(
        () => client.getMatch('GHOST1'),
        throwsA(
          isA<MultiplayerException>()
              .having((e) => e.statusCode, 'statusCode', 404)
              .having((e) => e.message, 'message', 'match "GHOST1" not found'),
        ),
      );
    });
  });
}
