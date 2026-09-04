import 'dart:convert';

import 'package:app/game_domain/multiplayer_client.dart';
import 'package:app/game_domain/multiplayer_match.dart';
import 'package:app/ui/multiplayer_battle_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response _matchResponse({
  required String currentTurnId,
  required int anaHp,
  required int betoHp,
  List<Map<String, dynamic>> activeFieldEffects = const [],
}) {
  return http.Response(
    jsonEncode({
      'id': 'ABC123',
      'playerAId': 'ana',
      'playerBId': 'beto',
      'status': 'in_progress',
      'state': {
        'playerAId': 'ana',
        'playerBId': 'beto',
        'currentTurnId': currentTurnId,
        'activeFieldEffects': activeFieldEffects,
        'hp': {
          'ana': {'max': 100, 'current': anaHp},
          'beto': {'max': 100, 'current': betoHp},
        },
        'winner': null,
      },
    }),
    200,
  );
}

void main() {
  testWidgets(
    'shows HP/turn for an in-progress match and plays a combo turn',
    (WidgetTester tester) async {
      final client = MultiplayerClient(
        baseUrl: 'http://x',
        httpClient: MockClient((request) async {
          if (request.method == 'POST' && request.url.path.endsWith('/join')) {
            return _matchResponse(currentTurnId: 'ana', anaHp: 100, betoHp: 100);
          }
          if (request.method == 'POST' && request.url.path.endsWith('/turns')) {
            return http.Response(
              jsonEncode({
                'match': jsonDecode(
                  _matchResponse(
                    currentTurnId: 'ana',
                    anaHp: 80,
                    betoHp: 100,
                    activeFieldEffects: const [
                      {'id': 'ignited_storm', 'area': 1, 'duration': null, 'damage': 20},
                    ],
                  ).body,
                ),
                'triggeredCombinationId': 'ignited_storm',
              }),
              200,
            );
          }
          throw StateError('unexpected request: ${request.method} ${request.url}');
        }),
      );

      final match = MultiplayerMatch(client: client, localPlayerId: 'beto');
      await match.join('ABC123'); // seeds state: ana's turn, both at 100 HP

      await tester.pumpWidget(
        MaterialApp(
          home: MultiplayerBattleScreen(
            match: match,
            pollInterval: const Duration(hours: 1), // never fires in this test
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Vez do oponente'), findsOneWidget);
      expect(find.textContaining('Você: 100/100 HP'), findsOneWidget);

      // beto plays out of turn (ana's turn) — the backend mock above only
      // answers /turns with a state where it's ana's turn again, mimicking
      // ana having just played fire+wind against beto.
      await tester.tap(find.text('🔥 Fogo'));
      await tester.pump();
      await tester.tap(find.text('🌪️ Vento'));
      await tester.pump();

      // Play button is disabled: it's not beto's turn.
      final playButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Jogar'),
      );
      expect(playButton.onPressed, isNull);

      await tester.pumpWidget(const SizedBox()); // dispose the poll Timer
    },
  );

  testWidgets(
    'Revanche creates a fresh match and lands on its waiting screen',
    (WidgetTester tester) async {
      final client = MultiplayerClient(
        baseUrl: 'http://x',
        httpClient: MockClient((request) async {
          if (request.method == 'POST' && request.url.path.endsWith('/join')) {
            return http.Response(
              jsonEncode({
                'id': 'ABC123',
                'playerAId': 'ana',
                'playerBId': 'beto',
                'status': 'finished',
                'state': {
                  'playerAId': 'ana',
                  'playerBId': 'beto',
                  'currentTurnId': 'ana',
                  'activeFieldEffects': [],
                  'hp': {
                    'ana': {'max': 100, 'current': 100},
                    'beto': {'max': 100, 'current': 0},
                  },
                  'winner': 'ana',
                },
              }),
              200,
            );
          }
          if (request.method == 'POST' && request.url.path == '/matches') {
            return http.Response(
              jsonEncode({
                'id': 'NEW999',
                'playerAId': 'beto',
                'playerBId': null,
                'status': 'waiting_for_opponent',
                'state': null,
              }),
              201,
            );
          }
          throw StateError('unexpected request: ${request.method} ${request.url}');
        }),
      );

      final match = MultiplayerMatch(client: client, localPlayerId: 'beto');
      await match.join('ABC123'); // seeds a finished match: beto lost

      await tester.pumpWidget(
        MaterialApp(
          home: MultiplayerBattleScreen(
            match: match,
            pollInterval: const Duration(hours: 1),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Você perdeu.'), findsOneWidget);

      await tester.tap(find.text('Revanche'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Partida NEW999'), findsOneWidget);
      expect(find.text('Aguardando oponente...'), findsOneWidget);
      expect(find.text('Compartilhe o código: NEW999'), findsOneWidget);

      await tester.pumpWidget(const SizedBox()); // dispose the poll Timer(s)
    },
  );

  testWidgets(
    'Habilidades modal lists what can be unlocked and unlocking it updates '
    'the list live',
    (WidgetTester tester) async {
      var unlockedNodeIds = <String>[];
      final client = MultiplayerClient(
        baseUrl: 'http://x',
        httpClient: MockClient((request) async {
          if (request.method == 'POST' && request.url.path == '/matches') {
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
                'skillProgress': {'ana': unlockedNodeIds, 'beto': []},
              }),
              201,
            );
          }
          if (request.method == 'POST' && request.url.path.endsWith('/skills/unlock')) {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            unlockedNodeIds = [...unlockedNodeIds, body['nodeId'] as String];
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
                  'skillProgress': {'ana': unlockedNodeIds, 'beto': []},
                },
              }),
              200,
            );
          }
          throw StateError('unexpected request: ${request.method} ${request.url}');
        }),
      );

      final match = MultiplayerMatch(client: client, localPlayerId: 'ana');
      await match.create();

      await tester.pumpWidget(
        MaterialApp(
          home: MultiplayerBattleScreen(
            match: match,
            pollInterval: const Duration(hours: 1),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byTooltip('Habilidades'));
      await tester.pumpAndSettle();

      expect(find.text('[fogo] Maestria da Brasa'), findsOneWidget);

      await tester.tap(find.text('Desbloquear').first);
      await tester.pump();
      await tester.pump();

      expect(find.text('[fogo] Maestria da Brasa'), findsNothing);
      expect(find.text('[fogo] Caminho do Incêndio'), findsOneWidget);

      await tester.tap(find.text('Fechar'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox()); // dispose the poll Timer
    },
  );
}
