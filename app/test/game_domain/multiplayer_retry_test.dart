import 'dart:convert';
import 'package:app/game_domain/multiplayer_client.dart';
import 'package:app/game_domain/multiplayer_match.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'polling respects Retry-After, backs off, recovers and never replays POST',
    () async {
      var now = DateTime(2026), gets = 0, posts = 0, status = 429;
      final room = {
        'id': 'ABC123',
        'revision': 0,
        'playerAId': 'a',
        'playerBId': null,
        'status': 'waiting_for_opponent',
        'state': null,
        'players': {
          'a': {'ready': false},
        },
        'skillProgress': <String, dynamic>{},
      };
      final client = MultiplayerClient(
        baseUrl: 'https://example.invalid',
        httpClient: MockClient((req) async {
          if (req.method == 'POST') {
            posts++;
            return http.Response(jsonEncode(room), 201);
          }
          gets++;
          return status == 200
              ? http.Response(jsonEncode(room), 200)
              : http.Response(
                  '{"error":"Aguarde"}',
                  status,
                  headers: status == 429 ? {'retry-after': '10'} : {},
                );
        }),
      );
      final match = MultiplayerMatch(
        client: client,
        localPlayerId: 'a',
        now: () => now,
      );
      await match.create();
      await match.refresh();
      await match.refresh();
      expect(gets, 1);
      expect(match.connectionError, contains('10s'));
      now = now.add(const Duration(seconds: 9));
      await match.refresh();
      expect(gets, 1);
      now = now.add(const Duration(seconds: 1));
      status = 503;
      await match.refresh();
      expect(gets, 2);
      expect(match.connectionError, contains('4s'));
      now = now.add(const Duration(seconds: 4));
      status = 200;
      await match.refresh();
      expect(gets, 3);
      expect(match.connectionError, isNull);
      status = 503;
      await match.refresh();
      expect(match.connectionError, contains('2s'));
      expect(posts, 1);
    },
  );
}
