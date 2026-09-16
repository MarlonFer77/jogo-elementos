import 'package:app/game_domain/training_match.dart';
import 'package:app/game_presentation/battle_scene_widget.dart';
import 'package:app/ui/training_screen.dart';
import 'package:battle_engine/battle_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final size in [
    const Size(360, 640),
    const Size(320, 568),
    const Size(740, 360),
  ]) {
    testWidgets('arena stays visible while commands scroll at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: TrainingScreen(
            initialMatch: TrainingMatch(
              initialProgressA: SkillProgress(
                defaultSkillTree,
                unlockedNodeIds: [
                  'unlock_fire',
                  'unlock_water',
                  'unlock_wind',
                  'unlock_ice',
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final arena = find.byType(BattleSceneWidget);
      final bounds = tester.getRect(arena);
      expect(bounds.top, greaterThanOrEqualTo(0));
      expect(bounds.bottom, lessThan(size.height));
      expect(find.byKey(const ValueKey('element-slot-3')), findsOneWidget);
      await tester.tap(find.text('Fogo'));
      await tester.pump();
      await tester.ensureVisible(find.text('Jogar'));
      expect(tester.getRect(arena), bounds);
      await tester.tap(find.text('Jogar'));
      await tester.pump();
      expect(tester.getRect(arena), bounds);
      expect(
        tester.widget<BattleSceneWidget>(arena).view.lastAttack?.elementIds,
        ['fire'],
      );
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Ataque em execução…'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'element exchange persists without playing; cancelling experiment keeps selection',
    (tester) async {
      final match = TrainingMatch(
        initialProgressA: SkillProgress(
          defaultSkillTree,
          unlockedNodeIds: [
            'unlock_fire',
            'unlock_water',
            'unlock_wind',
            'unlock_ice',
            'unlock_earth',
          ],
        ),
      );
      await tester.pumpWidget(
        MaterialApp(home: TrainingScreen(initialMatch: match)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.ensureVisible(find.text('Trocar elementos'));
      await tester.tap(find.text('Trocar elementos'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('❄️ Gelo'));
      await tester.pump();
      await tester.tap(find.text('🪨 Terra'));
      await tester.pump();
      await tester.tap(find.text('Salvar elementos'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(match.equippedElementIdsForCurrentPlayer, [
        'fire',
        'water',
        'wind',
        'earth',
      ]);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('training_elements_equipped_a'), [
        'fire',
        'water',
        'wind',
        'earth',
      ]);
      expect(match.turnsPlayed, 0);
      await tester.tap(find.text('Fogo'));
      await tester.pump();
      await tester.ensureVisible(find.text('Combinar elementos'));
      await tester.tap(find.text('Combinar elementos'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('💧 Água'));
      Navigator.of(tester.element(find.text('Experimente'))).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.ensureVisible(find.text('Jogar'));
      await tester.tap(find.text('Jogar'));
      await tester.pump();
      expect(
        match.playerBCurrentHp,
        95,
      ); // cancelled water selection never reached the action
    },
  );
}
