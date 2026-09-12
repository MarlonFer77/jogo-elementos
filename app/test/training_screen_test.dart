import 'package:app/game_domain/training_match.dart';
import 'package:app/game_presentation/pixel_menu_button.dart';
import 'package:app/main.dart';
import 'package:app/ui/training_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'selecting fire and wind then playing triggers Tempestade Ígnea and '
    'passes the turn to Jogador B',
    (WidgetTester tester) async {
      await tester.pumpWidget(const GameApp());
      await tester.pump(const Duration(milliseconds: 1)); // resolve o Future.delayed da checagem de atualização

      await tester.tap(find.text('MODO TREINO'));
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
      final match = TrainingMatch();
      for (var i = 0; i < 4; i++) {
        match.playElementIds(['fire', 'wind']); // Jogador A
        match.playElementIds(['ice']); // Jogador B, no damage
      }
      match.playElementIds(['fire', 'wind']); // 5th hit: defeats Jogador B
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
    final match = TrainingMatch();
    for (var i = 0; i < 4; i++) {
      match.playElementIds(['fire', 'wind']);
      match.playElementIds(['ice']);
    }
    match.playElementIds(['fire', 'wind']);

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
        'training_unlocked_a': ['ember_mastery'],
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
}
