import 'dart:async';
import 'dart:convert';
import 'package:app/game_domain/multiplayer_client.dart';
import 'package:app/game_domain/multiplayer_match.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> state({bool after = false}) => {
  'playerAId': 'a',
  'playerBId': 'b',
  'currentTurnId': after ? 'b' : 'a',
  'activeFieldEffects': [],
  'hp': {
    'a': {'max': 100, 'current': 100},
    'b': {'max': 100, 'current': 100},
  },
  'ap': {
    'a': {'max': 5, 'current': after ? 1 : 0},
    'b': {'max': 5, 'current': 0},
  },
  'combatantStatuses': {
    'a': after
        ? [
            {'effectId': 'guard', 'turnsRemaining': 1, 'damagePerTick': 0},
          ]
        : [],
    'b': [],
  },
  'winner': null,
};
Map<String, dynamic> matchJson({bool after = false}) => {
  'id': 'test',
  'playerAId': 'a',
  'playerBId': 'b',
  'status': 'in_progress',
  'revision': after ? 1 : 0,
  'players': {},
  'state': state(after: after),
  'skillProgress': {},
};
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'support preview uses server HP and AP without changing the match',
    () async {
      for (final purifying in [true, false]) {
        final before = state();
        before['hp']['a']['current'] = 50;
        before['ap']['a']['current'] = 4;
        before['ap']['b']['current'] = 2;
        final after = state(after: true);
        after['hp']['a']['current'] = purifying ? 62 : 50;
        after['hp']['b']['current'] = purifying ? 100 : 90;
        after['ap']['a']['current'] = 2;
        after['ap']['b']['current'] = purifying ? 2 : 1;
        final m = MultiplayerMatch(
          localPlayerId: 'a',
          client: MultiplayerClient(
            baseUrl: 'http://test',
            httpClient: MockClient(
              (request) async => http.Response(
                jsonEncode(
                  request.method == 'GET'
                      ? {...matchJson(), 'state': before}
                      : {
                          'match': {...matchJson(after: true), 'state': after},
                          'beforeState': before,
                        },
                ),
                200,
              ),
            ),
          ),
        );
        await m.reconnect('test');
        final original = m.match;
        final preview = await m.previewAction(
          purifying ? ['water', 'light'] : ['fire', 'shadow'],
        );
        expect(preview.selfHpLoss, purifying ? -12 : 0);
        expect(preview.opponentApLoss, purifying ? 0 : 1);
        expect(preview.cleanses, purifying);
        expect(preview.summary, contains(purifying ? '+12 HP' : '−1 AP'));
        expect(identical(original, m.match), isTrue);
      }
    },
  );
  test(
    'server preview is read-only and uses authoritative before/after snapshots',
    () async {
      final m = MultiplayerMatch(
        localPlayerId: 'a',
        client: MultiplayerClient(
          baseUrl: 'http://test',
          httpClient: MockClient((request) async {
            if (request.method == 'GET') {
              return http.Response(jsonEncode(matchJson()), 200);
            }
            expect(request.url.path, '/matches/test/preview');
            expect(jsonDecode(request.body), {
              'actorId': 'a',
              'elementIds': [],
              'kind': 'defend',
              'revision': 0,
            });
            return http.Response(
              jsonEncode({
                'match': matchJson(after: true),
                'beforeState': state(),
              }),
              200,
            );
          }),
        ),
      );
      await m.reconnect('test');
      final original = m.match;
      final preview = await m.previewAction([], defending: true);
      expect(preview.apCost, 0);
      expect(preview.apAfter, 1);
      expect(preview.opponentHpLoss, 0);
      expect(preview.effects.single, contains('Defesa 50%'));
      expect(identical(original, m.match), isTrue);
      expect(m.isMyTurn, isTrue);
    },
  );
  test(
    'pending defense cannot be sent twice and a stale poll cannot overwrite it',
    () async {
      final polling = Completer<http.Response>();
      final submit = Completer<http.Response>();
      var gets = 0, posts = 0;
      final m = MultiplayerMatch(
        localPlayerId: 'a',
        client: MultiplayerClient(
          baseUrl: 'http://test',
          httpClient: MockClient((request) async {
            if (request.method == 'GET') {
              if (gets++ == 0) {
                return http.Response(jsonEncode(matchJson()), 200);
              }
              return polling.future;
            }
            posts++;
            expect(request.url.path, '/matches/test/turns');
            expect((jsonDecode(request.body) as Map)['kind'], 'defend');
            return submit.future;
          }),
        ),
      );
      await m.reconnect('test');
      final refresh = m.refresh();
      final action = m.playElementIds([], defending: true);
      await expectLater(
        m.playElementIds([], defending: true),
        throwsStateError,
      );
      submit.complete(
        http.Response(jsonEncode({'match': matchJson(after: true)}), 200),
      );
      await action;
      polling.complete(http.Response(jsonEncode(matchJson()), 200));
      await refresh;
      expect(posts, 1);
      expect(m.isMyTurn, isFalse);
      expect(m.myAp, 1);
    },
  );
}
