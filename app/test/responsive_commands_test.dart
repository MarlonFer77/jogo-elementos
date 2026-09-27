import 'dart:convert';
import 'package:app/game_domain/training_match.dart';
import 'package:app/game_domain/multiplayer_match.dart';
import 'package:app/game_domain/multiplayer_client.dart';
import 'package:app/ui/training_screen.dart';
import 'package:app/ui/multiplayer_battle_screen.dart';
import 'package:app/ui/element_starter_screen.dart';
import 'package:battle_engine/battle_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'battle_result_test.dart' as fixture;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final size in [
    const Size(320, 568),
    const Size(360, 640),
    const Size(568, 320),
    const Size(740, 360),
  ]) {
    for (final online in [false, true]) {
      testWidgets('commands and execute stay visible: $size online=$online', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        Widget screen;
        if (online) {
          final snapshot = fixture.snapshot();
          final match = MultiplayerMatch(
            localPlayerId: 'a',
            client: MultiplayerClient(
              baseUrl: 'http://test',
              httpClient: MockClient(
                (request) async => http.Response(
                  jsonEncode(
                    request.url.path.endsWith('/preview')
                        ? {'match': snapshot, 'beforeState': snapshot['state']}
                        : snapshot,
                  ),
                  200,
                ),
              ),
            ),
          );
          await match.join('ABC123');
          screen = MultiplayerBattleScreen(match: match);
        } else {
          screen = TrainingScreen(
            initialMatch: TrainingMatch(
              initialProgressA: SkillProgress(
                defaultSkillTree,
                unlockedNodeIds: ElementUnlocks.all.map((e) => e.id).toList(),
              ),
            ),
          );
        }
        await tester.pumpWidget(MaterialApp(home: screen));
        await tester.pump();
        expect(find.text('Combinar').hitTestable(), findsOneWidget);
        expect(find.text('Defender').hitTestable(), findsOneWidget);
        await tester.tap(find.text('Defender'));
        await tester.pump();
        await tester.pump();
        expect(find.text('Confirmar defesa').hitTestable(), findsOneWidget);
        expect(find.text('Combinar').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Habilidades'));
        await tester.pump();
        expect(
          find.text('Defender').hitTestable().evaluate().length +
              find.text('Defesa ✓').hitTestable().evaluate().length,
          1,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
    testWidgets('starter choices and confirm fit $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: ElementStarterScreen(
            playerLabel: 'Jogador A',
            onConfirm: (_) {},
          ),
        ),
      );
      expect(find.textContaining('Veneno').hitTestable(), findsOneWidget);
      expect(find.text('Confirmar').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
