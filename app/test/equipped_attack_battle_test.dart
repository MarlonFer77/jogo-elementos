import 'package:app/game_domain/training_match.dart';
import 'package:app/game_presentation/battle_scene_widget.dart';
import 'package:app/game_presentation/pixel_menu_button.dart';
import 'package:app/ui/training_screen.dart';
import 'package:battle_engine/battle_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'equipped attack confirms, animates once and shows next player slots',
    (tester) async {
      final match = TrainingMatch(
        initialApA: const ApPool(max: 5, current: 2),
        initialProgressA: SkillProgress(
          defaultSkillTree,
          unlockedNodeIds: ['unlock_fire', 'unlock_wind'],
        ),
        initialLoadoutA: AttackLoadout(
          unlockedCombinationIds: {'ignited_storm'},
          equippedCombinationIds: ['ignited_storm'],
        ),
      );
      await tester.pumpWidget(
        MaterialApp(home: TrainingScreen(initialMatch: match)),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Habilidades'));
      await tester.pump();
      final slot = find.byKey(const ValueKey('attack-ignited_storm'));
      await tester.ensureVisible(slot);
      await tester.tap(slot);
      await tester.pump();
      expect(match.turnsPlayed, 0);
      final use = find.text('Usar habilidade · 3 AP');
      await tester.ensureVisible(use);
      final button = tester.widget<PixelMenuButton>(
        find.widgetWithText(PixelMenuButton, 'Usar habilidade · 3 AP'),
      );
      button.onPressed!();
      button.onPressed!(); // second queued tap must not play for the opponent
      await tester.pump();
      expect(match.turnsPlayed, 1);
      expect(match.playerBCurrentHp, 80);
      expect(find.text('Ataque em execução…'), findsOneWidget);
      expect(
        tester
            .widget<BattleSceneWidget>(find.byType(BattleSceneWidget))
            .view
            .lastAttack,
        isNotNull,
      );
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Ataque em execução…'), findsNothing);
      expect(slot, findsNothing);
      await tester.tap(find.text('Habilidades'));
      await tester.pump();
      expect(find.text('Não aprendido'), findsNWidgets(3));
    },
  );

  testWidgets(
    'persisted attack shows AP reason and cannot execute at narrow width',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({
        'training_unlocked_a': ['unlock_fire', 'unlock_wind'],
        'training_unlocked_b': ['unlock_fire', 'unlock_water'],
        'training_attacks_unlocked_a': ['ignited_storm'],
        'training_attacks_equipped_a': ['ignited_storm'],
      });
      await tester.pumpWidget(const MaterialApp(home: TrainingScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Habilidades'));
      await tester.pump();
      final slot = find.byKey(const ValueKey('attack-ignited_storm'));
      await tester.ensureVisible(slot);
      await tester.tap(slot);
      await tester.pump();
      expect(find.text('Faltam 2 AP.'), findsWidgets);
      expect(
        tester
            .widget<PixelMenuButton>(
              find.widgetWithText(PixelMenuButton, 'Usar habilidade · 3 AP'),
            )
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
