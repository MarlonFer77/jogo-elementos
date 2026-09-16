import 'package:app/game_domain/training_match.dart';
import 'package:app/game_presentation/battle_scene_widget.dart';
import 'package:flame/game.dart';
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
    const Size(568, 320),
  ]) {
    testWidgets('arena stays visible while commands scroll at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.view.padding = size.width > size.height
          ? const FakeViewPadding(left: 24, right: 24, bottom: 24)
          : const FakeViewPadding(top: 24, bottom: 24);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
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
      expect(bounds.bottom, lessThanOrEqualTo(size.height));
      final commands = tester.getRect(
        find.byKey(const ValueKey('battle-commands')),
      );
      if (size.width > size.height) {
        expect(bounds.right, lessThanOrEqualTo(commands.left));
        expect(bounds.height, greaterThan(size.height * .7));
      } else {
        expect(bounds.bottom, lessThanOrEqualTo(commands.top));
      }
      expect(find.byKey(const ValueKey('element-slot-3')), findsOneWidget);
      await tester.tap(find.text('Fogo'));
      await tester.pump();
      expect(find.text('Jogar').hitTestable(), findsOneWidget);
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

  testWidgets('rotation preserves selection, Flame instance and one attack', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final match = TrainingMatch(
      initialProgressA: SkillProgress(
        defaultSkillTree,
        unlockedNodeIds: ['unlock_fire', 'unlock_water'],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(home: TrainingScreen(initialMatch: match)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final gameWidget = find.byWidgetPredicate((widget) => widget is GameWidget);
    final game = tester.widget<GameWidget>(gameWidget).game;
    await tester.tap(find.text('Fogo'));
    await tester.pump();
    tester.view.physicalSize = const Size(740, 360);
    await tester.pump();
    expect(tester.widget<GameWidget>(gameWidget).game, same(game));
    expect(find.text('Jogar').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Jogar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    tester.view.physicalSize = const Size(360, 740);
    await tester.pump();
    expect(tester.widget<GameWidget>(gameWidget).game, same(game));
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(match.turnsPlayed, 1);
    expect(match.playerBCurrentHp, 95);
    expect(find.text('Ataque em execução…'), findsNothing);
    expect(find.text('Vez de: Jogador B'), findsOneWidget);
    tester.view.physicalSize = const Size(740, 360);
    await tester.pump();
    expect(tester.widget<GameWidget>(gameWidget).game, same(game));
    expect(find.text('Ataque em execução…'), findsNothing);
    expect(tester.takeException(), isNull);
  });

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

  testWidgets('landscape sheets stay usable with safe insets and rotation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(740, 360);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(
      left: 24,
      right: 24,
      bottom: 24,
    );
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    final match = TrainingMatch(
      initialProgressA: SkillProgress(
        defaultSkillTree,
        unlockedNodeIds: ['unlock_fire', 'unlock_water'],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(home: TrainingScreen(initialMatch: match)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.ensureVisible(find.text('Combinar elementos'));
    await tester.tap(find.text('Combinar elementos'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('🔥 Fogo'));
    await tester.pump();
    tester.view.physicalSize = const Size(360, 740);
    await tester.pump();
    await tester.tap(find.text('💧 Água'));
    await tester.pump();
    await tester.ensureVisible(find.text('Confirmar'));
    await tester.tap(find.text('Confirmar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(match.turnsPlayed, 0);
    expect(find.text('Combinar: Fogo + Água'), findsOneWidget);
    tester.view.physicalSize = const Size(740, 360);
    await tester.pump();
    await tester.tap(find.text('Habilidades'));
    await tester.pump();
    await tester.ensureVisible(find.text('Trocar'));
    await tester.tap(find.text('Trocar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Habilidades · 3 slots'), findsOneWidget);
    expect(find.byTooltip('Fechar habilidades').hitTestable(), findsOneWidget);
    await tester.tap(find.byTooltip('Fechar habilidades'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(match.turnsPlayed, 0);
    expect(tester.takeException(), isNull);
  });
}
