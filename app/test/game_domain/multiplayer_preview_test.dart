import 'dart:async';
import 'dart:convert';
import 'package:app/game_domain/multiplayer_client.dart';
import 'package:app/game_domain/multiplayer_match.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

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
  'state': state(after: after),
  'skillProgress': {},
};
void main() {
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
