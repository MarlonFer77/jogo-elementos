import 'dart:convert';
import 'package:app/game_domain/battle_progress.dart';
import 'package:app/game_domain/multiplayer_client.dart';
import 'package:app/game_domain/multiplayer_match.dart';
import 'package:app/game_domain/training_match.dart';
import 'package:app/game_presentation/battle_result_panel.dart';
import 'package:app/game_presentation/battle_scene_widget.dart';
import 'package:app/ui/attacks_screen.dart';
import 'package:app/ui/multiplayer_battle_screen.dart';
import 'package:app/ui/training_screen.dart';
import 'package:battle_engine/battle_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> snapshot({bool finished = false}) => {
  'id': 'ABC123',
  'revision': finished ? 4 : 3,
  'status': finished ? 'finished' : 'in_progress',
  'playerAId': 'a',
  'playerBId': 'b',
  'players': {
    for (final id in ['a', 'b'])
      id: {
        'ready': true,
        'elements': ['fire', 'wind'],
        'attacks': finished ? ['ignited_storm'] : [],
        'discoveries': finished ? ['ignited_storm'] : [],
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
      'a': {'max': 100, 'current': 80},
      'b': {'max': 100, 'current': finished ? 0 : 100},
    },
    'ap': {
      for (final id in ['a', 'b']) id: {'max': 5, 'current': 3},
    },
    'winner': finished ? 'a' : null,
  },
};

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'gain snapshots exclude old progress, duplicates and missing history',
    () {
      final oldIds = ['old'];
      final initial = BattleProgress(attacks: oldIds, skills: ['unlock_fire']);
      oldIds.add('new');
      final current = BattleProgress(
        attacks: ['old', 'new', 'new'],
        skills: ['unlock_fire', 'unlock_wind'],
      );
      expect(current.gainedSince(initial)!.attacks, {'new'});
      expect(current.gainedSince(initial)!.skills, {'unlock_wind'});
      expect(current.gainedSince(null), isNull);
    },
  );

  test(
    'server gains survive refresh, reconnect explicitly loses baseline',
    () async {
      var finished = false;
      final match = MultiplayerMatch(
        localPlayerId: 'a',
        client: MultiplayerClient(
          baseUrl: 'http://test',
          httpClient: MockClient(
            (_) async =>
                http.Response(jsonEncode(snapshot(finished: finished)), 200),
          ),
        ),
      );
      await match.join('ABC123');
      expect(match.battleGains!.skills, isEmpty);
      finished = true;
      await match.refresh();
      expect(match.battleGains!.attacks, {'ignited_storm'});
      await match.refresh();
      expect(match.battleGains!.attacks, {'ignited_storm'});
      await match.reconnect('ABC123');
      await match.refresh();
      expect(match.battleGains, isNull);
    },
  );

  for (final size in [const Size(360, 640), const Size(740, 360)]) {
    testWidgets(
      'finished multiplayer retains arena and read-only abilities at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var requests = 0;
        final match = MultiplayerMatch(
          localPlayerId: 'a',
          client: MultiplayerClient(
            baseUrl: 'http://test',
            httpClient: MockClient((_) async {
              requests++;
              return http.Response(jsonEncode(snapshot(finished: true)), 200);
            }),
          ),
        );
        await match.reconnect('ABC123');
        await tester.pumpWidget(
          MaterialApp(home: MultiplayerBattleScreen(match: match)),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('VITÓRIA'), findsOneWidget);
        expect(find.byType(BattleSceneWidget), findsOneWidget);
        expect(find.textContaining('Partida retomada:'), findsOneWidget);
        expect(find.text('Revanche').hitTestable(), findsOneWidget);
        expect(find.text('Voltar ao menu').hitTestable(), findsOneWidget);
        await tester.ensureVisible(find.text('Revisar habilidades'));
        await tester.tap(find.text('Revisar habilidades'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(
          tester.widget<AttacksScreen>(find.byType(AttacksScreen)).readOnly,
          isTrue,
        );
        await tester.tap(find.text('Tempestade Ígnea').first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.textContaining('3 AP base'), findsOneWidget);
        expect(
          requests,
          1,
        ); // Review must not write equipment on a finished match.
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'training result reviews both players and rematch preserves progress',
    (tester) async {
      final match = TrainingMatch(
        initialProgressA: SkillProgress(
          defaultSkillTree,
          unlockedNodeIds: ['unlock_fire'],
        ),
        initialProgressB: SkillProgress(
          defaultSkillTree,
          unlockedNodeIds: ['unlock_fire'],
        ),
        initialDiscoveryBook: DiscoveryBook(
          discoveredCombinationIds: {'ignited_storm'},
        ),
      );
      for (var i = 0; i < 100 && !match.isOver; i++) {
        match.playElementIds(['fire']);
      }
      expect(match.isOver, isTrue);
      expect(match.gainsForPlayer(true).discoveries, isEmpty);
      await tester.pumpWidget(
        MaterialApp(home: TrainingScreen(initialMatch: match)),
      );
      await tester.pump();
      expect(find.byType(BattleResultPanel), findsOneWidget);
      expect(find.byType(BattleSceneWidget), findsOneWidget);
      expect(find.text('Habilidades · Jogador A'), findsOneWidget);
      expect(find.text('Habilidades · Jogador B'), findsOneWidget);
      await tester.ensureVisible(find.text('Revanche'));
      await tester.tap(find.text('Revanche'));
      await tester.pump();
      expect(find.byType(BattleResultPanel), findsNothing);
      final next = match.startNewBattleKeepingProgress();
      expect(next.discoveredCombinationIds, ['ignited_storm']);
      expect(next.gainsForPlayer(true).discoveries, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
