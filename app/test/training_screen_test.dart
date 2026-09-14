import 'package:app/game_domain/training_match.dart';
import 'package:app/game_presentation/pixel_menu_button.dart';
import 'package:app/main.dart';
import 'package:app/ui/training_screen.dart';
import 'package:battle_engine/battle_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

SkillProgress _allElementsUnlocked() => SkillProgress(
      defaultSkillTree,
      unlockedNodeIds: ElementUnlocks.all.map((u) => u.id).toList(),
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'selecting fire and wind then playing triggers Tempestade Ígnea and '
    'passes the turn to Jogador B',
    (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: TrainingScreen(
          initialMatch: TrainingMatch(
            initialApA: const ApPool(max: 5, current: 3),
            initialProgressA: _allElementsUnlocked(),
          ),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Vez de: Jogador A'), findsOneWidget);

      await tester.tap(find.text('Escolher elementos'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('🔥 Fogo'));
      await tester.pump();
      await tester.tap(find.text('🌪️ Vento'));
      await tester.pump();

      await tester.tap(find.text('Confirmar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.ensureVisible(find.text('Jogar'));
      await tester.tap(find.text('Jogar'));
      await tester.pump();

      expect(find.text('Vez de: Jogador B'), findsOneWidget);
      expect(
        find.text('Última combinação: Tempestade Ígnea'),
        findsOneWidget,
      );
      expect(find.text('Descobertas: 1/3'), findsOneWidget);
      expect(find.textContaining('80/100 HP'), findsOneWidget);
    },
  );

  testWidgets('the play button is disabled until an element is selected',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'training_unlocked_a': ['unlock_fire'],
      'training_unlocked_b': ['unlock_fire'],
    });

    await tester.pumpWidget(const GameApp());
    await tester.pump(const Duration(milliseconds: 1)); // resolve o Future.delayed da checagem de atualização

    await tester.tap(find.text('MODO TREINO'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final button = tester.widget<PixelMenuButton>(
      find.widgetWithText(PixelMenuButton, 'Jogar'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets(
    'unlocking Maestria da Brasa applies Queimadura to the opponent on the '
    'next action',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'training_unlocked_a': ['unlock_fire'],
        'training_unlocked_b': ['unlock_fire'],
      });

      await tester.pumpWidget(const GameApp());
      await tester.pump(const Duration(milliseconds: 1)); // resolve o Future.delayed da checagem de atualização

      await tester.tap(find.text('MODO TREINO'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.byIcon(Icons.auto_awesome));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('Maestria da Brasa'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('Desbloquear'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.byType(BackButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

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

      expect(
        find.text('Efeitos aplicados: Queimadura'),
        findsOneWidget,
      );
      expect(find.text('🔥'), findsOneWidget); // badge de Queimadura em Jogador B
    },
  );

  testWidgets(
    'shows the winner and a rematch button once the battle ends, hiding '
    'the play form',
    (WidgetTester tester) async {
      final match = TrainingMatch(
        initialProgressA: SkillProgress(defaultSkillTree, unlockedNodeIds: ['unlock_fire']),
        initialProgressB: SkillProgress(defaultSkillTree, unlockedNodeIds: ['unlock_ice']),
      );
      // 5 basic damage per hit (single element, always free) — 20 hits
      // defeat 100 HP.
      for (var i = 0; i < 19; i++) {
        match.playElementIds(['fire']); // Jogador A
        match.playElementIds(['ice']); // Jogador B
      }
      match.playElementIds(['fire']); // 20th hit: defeats Jogador B
      expect(match.isOver, isTrue); // sanity check on the setup itself

      await tester.pumpWidget(
        MaterialApp(home: TrainingScreen(initialMatch: match)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.textContaining('Vencedor: Jogador A'), findsOneWidget);
      expect(find.text('Nova partida'), findsOneWidget);
      expect(find.text('Jogar'), findsNothing);
    },
  );

  testWidgets('Nova partida starts a fresh match', (WidgetTester tester) async {
    final match = TrainingMatch(
      initialProgressA: SkillProgress(defaultSkillTree, unlockedNodeIds: ['unlock_fire']),
      initialProgressB: SkillProgress(defaultSkillTree, unlockedNodeIds: ['unlock_ice']),
    );
    for (var i = 0; i < 19; i++) {
      match.playElementIds(['fire']);
      match.playElementIds(['ice']);
    }
    match.playElementIds(['fire']);

    await tester.pumpWidget(
      MaterialApp(home: TrainingScreen(initialMatch: match)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.ensureVisible(find.text('Nova partida'));
    await tester.tap(find.text('Nova partida'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Vez de: Jogador A'), findsOneWidget);
    expect(find.text('Jogar'), findsOneWidget);
  });

  testWidgets(
    'loads persisted Skill Tree progress before showing the play form',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'training_unlocked_a': ['ember_mastery', 'unlock_fire'],
        'training_unlocked_b': ['unlock_fire'],
      });

      await tester.pumpWidget(const MaterialApp(home: TrainingScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));

      await tester.tap(find.byIcon(Icons.auto_awesome));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('Caminho do Incêndio'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Desbloquear'), findsOneWidget);
    },
  );

  testWidgets(
    'shows a friendly message when a combo is attempted without enough AP',
    (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: TrainingScreen(
          initialMatch: TrainingMatch(
            initialProgressA: SkillProgress(
              defaultSkillTree,
              unlockedNodeIds: ['unlock_fire', 'unlock_wind'],
            ),
          ), // AP começa em 0
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('Escolher elementos'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('🔥 Fogo'));
      await tester.pump();
      await tester.tap(find.text('🌪️ Vento'));
      await tester.pump();

      await tester.tap(find.text('Confirmar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.ensureVisible(find.text('Jogar'));
      await tester.tap(find.text('Jogar'));
      await tester.pump();

      expect(find.text('AP insuficiente para essa combinação.'), findsOneWidget);
      expect(find.text('Vez de: Jogador A'), findsOneWidget); // turno não passou
    },
  );

  testWidgets(
    'shows the starting-element picker for Jogador A when no progress is '
    'saved yet, then for Jogador B, then the normal play form',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: TrainingScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));

      expect(find.textContaining('Jogador A'), findsWidgets);

      await tester.tap(find.text('🔥 Fogo'));
      await tester.pump();
      await tester.tap(find.text('🌪️ Vento'));
      await tester.pump();
      await tester.tap(find.text('Confirmar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.textContaining('Jogador B'), findsWidgets);

      await tester.tap(find.text('🔥 Fogo'));
      await tester.pump();
      await tester.tap(find.text('🌪️ Vento'));
      await tester.pump();
      await tester.tap(find.text('Confirmar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Vez de: Jogador A'), findsOneWidget);
    },
  );

  testWidgets('locked elements appear with a lock icon and are not '
      'selectable', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: TrainingScreen(
        initialMatch: TrainingMatch(
          initialProgressA: SkillProgress(
            defaultSkillTree,
            unlockedNodeIds: ['unlock_fire'],
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Escolher elementos'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('🔥 Fogo'), findsOneWidget);
    expect(find.text('🔒 Água'), findsOneWidget);
  });
}
