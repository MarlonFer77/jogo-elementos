import 'dart:convert';
import 'package:app/game_domain/multiplayer_client.dart';
import 'package:app/game_domain/multiplayer_match.dart';
import 'package:app/ui/multiplayer_battle_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> room() => {
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
  'serverNow': 100000,
  'deadline': 400000,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'countdown uses server offset; zero never declares a local result',
    () async {
      var now = DateTime(2030);
      final match = MultiplayerMatch(
        localPlayerId: 'a',
        now: () => now,
        client: MultiplayerClient(
          baseUrl: 'http://x',
          httpClient: MockClient(
            (_) async => http.Response(jsonEncode(room()), 200),
          ),
        ),
      );
      await match.reconnect('ABC123');
      expect(match.secondsRemaining, 300);
      now = now.add(const Duration(seconds: 305));
      expect(match.secondsRemaining, 0);
      expect(match.isFinished, isFalse);
    },
  );

  for (final size in [const Size(360, 640), const Size(740, 360)]) {
    testWidgets('confirmed cancellation, not defeat, at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var posts = 0;
      final match = MultiplayerMatch(
        localPlayerId: 'a',
        client: MultiplayerClient(
          baseUrl: 'http://x',
          httpClient: MockClient((req) async {
            final data = room();
            if (req.method == 'POST') {
              posts++;
              expect(req.url.path, '/matches/ABC123/surrender');
              expect(jsonDecode(req.body), {'playerId': 'a'});
              data.addAll({
                'revision': 1,
                'status': 'finished',
                'ending': {'reason': 'cancelled', 'playerId': 'a'},
              });
            }
            return http.Response(jsonEncode(data), 200);
          }),
        ),
      );
      await match.reconnect('ABC123');
      await tester.pumpWidget(
        MaterialApp(
          home: MultiplayerBattleScreen(
            match: match,
            pollInterval: const Duration(hours: 1),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byType(BackButton));
      await tester.pump(const Duration(milliseconds: 400));
      expect(posts, 0);
      await tester.tap(find.text('Cancelar sala'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(posts, 1);
      expect(find.text('SALA ENCERRADA'), findsOneWidget);
      expect(find.textContaining('Sem vencedor'), findsOneWidget);
      expect(match.wasCancelled, isTrue);
      expect(match.isMyTurn, isFalse);
      await match.surrender();
      expect(posts, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
