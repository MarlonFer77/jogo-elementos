import 'dart:convert';

import 'package:app/game_domain/multiplayer_client.dart';
import 'package:app/game_domain/multiplayer_match.dart';
import 'package:app/game_presentation/pixel_menu_button.dart';
import 'package:app/game_presentation/battle_scene_widget.dart';
import 'package:app/game_presentation/skill_tree_layout.dart';
import 'package:app/game_presentation/skill_tree_node_widget.dart';
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
  Map<String, dynamic> combatantStatuses = const {},
  Map<String, dynamic> ap = const {},
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
        'combatantStatuses': combatantStatuses,
        'ap': ap,
        'winner': null,
      },
    }),
    200,
  );
}

void main() {
  testWidgets('frozen local player can only submit thaw', (tester) async {
    late Map<String, dynamic> submitted;
    final client = MultiplayerClient(
      baseUrl: 'http://x',
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/join')) {
          return _matchResponse(
            currentTurnId: 'ana',
            anaHp: 90,
            betoHp: 100,
            combatantStatuses: const {
              'ana': [
                {
                  'effectId': 'freeze',
                  'turnsRemaining': null,
                  'damagePerTick': 0,
                },
              ],
              'beto': [],
            },
            ap: const {
              'ana': {'max': 5, 'current': 2},
              'beto': {'max': 5, 'current': 3},
            },
          );
        }
        if (request.url.path.endsWith('/turns')) {
          submitted = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'match': jsonDecode(
                _matchResponse(
                  currentTurnId: 'beto',
                  anaHp: 90,
                  betoHp: 100,
                  combatantStatuses: const {'ana': [], 'beto': []},
                  ap: const {
                    'ana': {'max': 5, 'current': 2},
                    'beto': {'max': 5, 'current': 3},
                  },
                ).body,
              ),
              'triggeredCombinationId': null,
            }),
            200,
          );
        }
        throw StateError('unexpected request');
      }),
    );
    final match = MultiplayerMatch(client: client, localPlayerId: 'ana');
    await match.join('ABC123');
    await tester.pumpWidget(
      MaterialApp(
        home: MultiplayerBattleScreen(
          match: match,
          pollInterval: const Duration(hours: 1),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Sua vez · CONGELADO'), findsOneWidget);
    expect(find.text('Quebrar gelo'), findsOneWidget);
    await tester.ensureVisible(find.text('Quebrar gelo'));
    await tester.tap(find.text('Quebrar gelo'));
    await tester.pump();
    await tester.pump();
    expect(submitted, {'actorId': 'ana', 'elementIds': [], 'kind': 'thaw'});
    expect(match.myAp, 2);
    expect(match.amIFrozen, isFalse);
    expect(match.isMyTurn, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('successful basic attack produces a proximity animation event', (
    tester,
  ) async {
    final client = MultiplayerClient(
      baseUrl: 'http://x',
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/join')) {
          return _matchResponse(currentTurnId: 'ana', anaHp: 100, betoHp: 100);
        }
        if (request.url.path.endsWith('/turns')) {
          return http.Response(
            jsonEncode({
              'match': jsonDecode(
                _matchResponse(
                  currentTurnId: 'beto',
                  anaHp: 100,
                  betoHp: 95,
                ).body,
              ),
              'triggeredCombinationId': null,
            }),
            200,
          );
        }
        throw StateError('unexpected request');
      }),
    );
    final match = MultiplayerMatch(client: client, localPlayerId: 'ana');
    await match.join('ABC123');
    await tester.pumpWidget(
      MaterialApp(
        home: MultiplayerBattleScreen(
          match: match,
          pollInterval: const Duration(hours: 1),
        ),
      ),
    );
    await tester.pump();
    await tester.ensureVisible(find.text('Escolher elementos'));
    await tester.tap(find.text('Escolher elementos'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('🔥 Fogo'));
    await tester.pump();
    await tester.tap(find.text('Confirmar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.ensureVisible(find.text('Jogar'));
    await tester.tap(find.text('Jogar'));
    await tester.pump();
    await tester.pump();
    final event = tester
        .widget<BattleSceneWidget>(find.byType(BattleSceneWidget))
        .view
        .lastAttack;
    expect(event?.elementIds, ['fire']);
    expect(event?.comboName, isNull);
    expect(event?.damage, 5);
    expect(match.opponentCurrentHp, 95);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows HP/turn for an in-progress match and plays a combo turn', (
    WidgetTester tester,
  ) async {
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
                    {
                      'id': 'ignited_storm',
                      'area': 1,
                      'duration': null,
                      'damage': 20,
                    },
                  ],
                ).body,
              ),
              'triggeredCombinationId': 'ignited_storm',
            }),
            200,
          );
        }
        throw StateError(
          'unexpected request: ${request.method} ${request.url}',
        );
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
    expect(find.text('Você'), findsOneWidget);
    expect(find.text('Oponente'), findsOneWidget);
    expect(find.textContaining('100/100 HP'), findsNWidgets(2));

    // beto can't even open the element picker out of turn (ana's turn) —
    // "Escolher elementos" is disabled, same as "Jogar".
    final pickerButton = tester.widget<PixelMenuButton>(
      find.widgetWithText(PixelMenuButton, 'Escolher elementos'),
    );
    expect(pickerButton.onPressed, isNull);

    // Play button is disabled: it's not beto's turn.
    final playButton = tester.widget<PixelMenuButton>(
      find.widgetWithText(PixelMenuButton, 'Jogar'),
    );
    expect(playButton.onPressed, isNull);

    await tester.pumpWidget(const SizedBox()); // dispose the poll Timer
  });

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
          throw StateError(
            'unexpected request: ${request.method} ${request.url}',
          );
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
          if (request.method == 'POST' &&
              request.url.path.endsWith('/skills/unlock')) {
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
          throw StateError(
            'unexpected request: ${request.method} ${request.url}',
          );
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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        tester
            .widget<SkillTreeNodeWidget>(
              find.widgetWithText(SkillTreeNodeWidget, 'Maestria da Brasa'),
            )
            .state,
        SkillTreeNodeState.available,
      );

      await tester.tap(find.text('Maestria da Brasa'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('Desbloquear'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        tester
            .widget<SkillTreeNodeWidget>(
              find.widgetWithText(SkillTreeNodeWidget, 'Maestria da Brasa'),
            )
            .state,
        SkillTreeNodeState.unlocked,
      );
      expect(
        tester
            .widget<SkillTreeNodeWidget>(
              find.widgetWithText(SkillTreeNodeWidget, 'Caminho do Incêndio'),
            )
            .state,
        SkillTreeNodeState.available,
      );

      await tester.tap(find.byType(BackButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpWidget(const SizedBox()); // dispose the poll Timer
    },
  );
}
