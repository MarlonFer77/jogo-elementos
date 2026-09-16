import 'package:app/game_presentation/pixel_menu_button.dart';
import 'package:app/ui/element_starter_screen.dart';
import 'package:app/ui/training_screen.dart';
import 'package:app/game_presentation/battle_scene_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final size in [
    const Size(320, 568),
    const Size(360, 740),
    const Size(568, 320),
    const Size(740, 360),
  ]) {
    testWidgets('preparation flows into battle and persists at $size', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      await tester.pumpWidget(const MaterialApp(home: TrainingScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('TREINO · PREPARAÇÃO'), findsOneWidget);
      expect(find.byType(BattleSceneWidget), findsNothing);
      for (final label in ['Preparar Jogador B', 'Entrar na batalha']) {
        await tester.tap(find.text('🔥 Fogo'));
        await tester.pump();
        await tester.tap(find.text('💧 Água'));
        await tester.pump();
        expect(find.text(label).hitTestable(), findsOneWidget);
        await tester.tap(find.text(label));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      }
      expect(find.byType(BattleSceneWidget), findsOneWidget);
      expect(find.text('Vez de: Jogador A'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('training_unlocked_a'), [
        'unlock_fire',
        'unlock_water',
      ]);
      expect(prefs.getStringList('training_unlocked_b'), [
        'unlock_fire',
        'unlock_water',
      ]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(const MaterialApp(home: TrainingScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(ElementStarterScreen), findsNothing);
      expect(find.byType(BattleSceneWidget), findsOneWidget);
    });
  }

  testWidgets('rotation keeps initial choices and allows replacing one', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    List<String>? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: ElementStarterScreen(
          playerLabel: 'Jogador A',
          onConfirm: (ids) => selected = ids,
        ),
      ),
    );
    await tester.tap(find.text('🔥 Fogo'));
    await tester.pump();
    tester.view.physicalSize = const Size(740, 360);
    await tester.pump();
    await tester.tap(find.text('💧 Água'));
    await tester.pump();
    await tester.tap(find.text('🔥 Fogo'));
    await tester.pump();
    await tester.tap(find.text('🌪️ Vento'));
    await tester.pump();
    await tester.tap(find.text('Confirmar'));
    expect(selected, ['water', 'wind']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the player label in the title', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ElementStarterScreen(playerLabel: 'Jogador A', onConfirm: (_) {}),
      ),
    );
    await tester.pump();

    expect(find.textContaining('Jogador A'), findsWidgets);
  });

  testWidgets('Confirmar is disabled with 0 or 1 elements selected, '
      'enabled with exactly 2', (tester) async {
    List<String>? confirmed;
    await tester.pumpWidget(
      MaterialApp(
        home: ElementStarterScreen(
          playerLabel: 'Jogador A',
          onConfirm: (ids) => confirmed = ids,
        ),
      ),
    );
    await tester.pump();

    var button = tester.widget<PixelMenuButton>(
      find.widgetWithText(PixelMenuButton, 'Confirmar'),
    );
    expect(button.onPressed, isNull);

    await tester.tap(find.text('🔥 Fogo'));
    await tester.pump();

    button = tester.widget<PixelMenuButton>(
      find.widgetWithText(PixelMenuButton, 'Confirmar'),
    );
    expect(button.onPressed, isNull);

    await tester.tap(find.text('🌪️ Vento'));
    await tester.pump();

    button = tester.widget<PixelMenuButton>(
      find.widgetWithText(PixelMenuButton, 'Confirmar'),
    );
    expect(button.onPressed, isNotNull);

    await tester.tap(find.text('Confirmar'));
    await tester.pump();

    expect(confirmed, equals(['fire', 'wind']));
  });

  testWidgets('selecting a 3rd element does not replace the first 2', (
    tester,
  ) async {
    List<String>? confirmed;
    await tester.pumpWidget(
      MaterialApp(
        home: ElementStarterScreen(
          playerLabel: 'Jogador A',
          onConfirm: (ids) => confirmed = ids,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('🔥 Fogo'));
    await tester.pump();
    await tester.tap(find.text('🌪️ Vento'));
    await tester.pump();
    await tester.tap(find.text('💧 Água'));
    await tester.pump();

    await tester.tap(find.text('Confirmar'));
    await tester.pump();

    expect(confirmed, equals(['fire', 'wind']));
  });
}
