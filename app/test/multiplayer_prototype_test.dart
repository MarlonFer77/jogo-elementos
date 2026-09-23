import 'dart:convert';
import 'package:app/game_domain/multiplayer_client.dart';
import 'package:app/game_domain/multiplayer_match.dart';
import 'package:app/ui/multiplayer_battle_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final size in [const Size(360, 640), const Size(740, 360)]) {
    testWidgets('multiplayer equipment is usable at $size', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final snapshot = {
        'id': 'ABC123',
        'revision': 3,
        'status': 'in_progress',
        'playerAId': 'a',
        'playerBId': 'b',
        'players': {
          for (final id in ['a', 'b'])
            id: {
              'ready': true,
              'elements': ['fire', 'wind'],
              'attacks': ['ignited_storm'],
              'discoveries': ['ignited_storm'],
              'turns': 2,
            },
        },
        'skillProgress': {
          for (final id in ['a', 'b']) id: ['unlock_fire', 'unlock_wind'],
        },
        'state': {
          'playerAId': 'a',
          'playerBId': 'b',
          'currentTurnId': 'a',
          'activeFieldEffects': [],
          'combatantStatuses': {},
          'hp': {
            for (final id in ['a', 'b']) id: {'max': 100, 'current': 100},
          },
          'ap': {
            for (final id in ['a', 'b']) id: {'max': 5, 'current': 3},
          },
          'winner': null,
        },
      };
      final client = MultiplayerClient(
        baseUrl: 'http://test',
        httpClient: MockClient((request) async {
          expect(request.headers['Authorization'], startsWith('Bearer '));
          if (request.url.path.endsWith('/preview')) {
            expect(jsonDecode(request.body)['revision'], 3);
            return http.Response(
              jsonEncode({'match': snapshot, 'beforeState': snapshot['state']}),
              200,
            );
          }
          return http.Response(jsonEncode(snapshot), 200);
        }),
      );
      final match = MultiplayerMatch(client: client, localPlayerId: 'a');
      await match.join('ABC123');
      expect(await client.lastSession(), ('a', 'ABC123'));
      await tester.pumpWidget(
        MaterialApp(home: MultiplayerBattleScreen(match: match)),
      );
      await tester.pump();
      expect(find.text('Vazio'), findsNWidgets(2));
      await tester.ensureVisible(find.text('Habilidades'));
      await tester.tap(find.text('Habilidades'));
      await tester.pump();
      expect(find.text('Habilidade vazia'), findsNWidgets(2));
      expect(find.textContaining('Tempestade Ígnea'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
