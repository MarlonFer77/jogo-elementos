import 'package:app/game_domain/battle_scene_view.dart';
import 'package:app/game_presentation/battle_hud_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows both labels and HP for each side', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: BattleHudWidget(
          view: BattleSceneView(
            leftCurrentHp: 80, leftMaxHp: 100,
            rightCurrentHp: 40, rightMaxHp: 100,
            isLeftTurn: true,
            leftLabel: 'Jogador A',
            rightLabel: 'Jogador B',
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Jogador A'), findsOneWidget);
    expect(find.text('Jogador B'), findsOneWidget);
    expect(find.textContaining('80/100 HP'), findsOneWidget);
    expect(find.textContaining('40/100 HP'), findsOneWidget);
  });

  testWidgets('marks the left panel as active when isLeftTurn is true',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: BattleHudWidget(
          view: BattleSceneView(
            leftCurrentHp: 100, leftMaxHp: 100,
            rightCurrentHp: 100, rightMaxHp: 100,
            isLeftTurn: true,
            leftLabel: 'Jogador A',
            rightLabel: 'Jogador B',
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('▶'), findsOneWidget);
    expect(find.text('◀'), findsNothing);
  });

  testWidgets('marks the right panel as active when isLeftTurn is false',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: BattleHudWidget(
          view: BattleSceneView(
            leftCurrentHp: 100, leftMaxHp: 100,
            rightCurrentHp: 100, rightMaxHp: 100,
            isLeftTurn: false,
            leftLabel: 'Jogador A',
            rightLabel: 'Jogador B',
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('◀'), findsOneWidget);
    expect(find.text('▶'), findsNothing);
  });
}
