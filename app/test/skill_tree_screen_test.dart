import 'package:app/game_presentation/skill_tree_layout.dart';
import 'package:app/game_presentation/skill_tree_node_widget.dart';
import 'package:app/ui/skill_tree_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('tapping a locked node shows its missing prerequisites',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SkillTreeScreen(
        title: 'Habilidades',
        unlockedNodeIds: const [],
        canUnlockNow: true,
        onUnlock: (_) async => throw StateError('should not be called'),
      ),
    ));
    await tester.pump();

    await tester.tap(find.text('Caminho do Incêndio'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('Requer: Maestria da Brasa'), findsOneWidget);
    expect(find.text('Desbloquear'), findsNothing);
  });

  testWidgets(
      'tapping an available node unlocks it on success and updates the '
      'node state', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SkillTreeScreen(
        title: 'Habilidades',
        unlockedNodeIds: const [],
        canUnlockNow: true,
        onUnlock: (nodeId) async => null,
      ),
    ));
    await tester.pump();

    expect(
      tester.widget<SkillTreeNodeWidget>(
        find.widgetWithText(SkillTreeNodeWidget, 'Maestria da Brasa'),
      ).state,
      SkillTreeNodeState.available,
    );

    await tester.tap(find.text('Maestria da Brasa'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Desbloquear'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      tester.widget<SkillTreeNodeWidget>(
        find.widgetWithText(SkillTreeNodeWidget, 'Maestria da Brasa'),
      ).state,
      SkillTreeNodeState.unlocked,
    );
  });

  testWidgets(
      "an available node shows a turn notice instead of the button when "
      "it's not the player's turn", (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SkillTreeScreen(
        title: 'Habilidades',
        unlockedNodeIds: const [],
        canUnlockNow: false,
        onUnlock: (_) async => throw StateError('should not be called'),
      ),
    ));
    await tester.pump();

    await tester.tap(find.text('Maestria da Brasa'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Só dá pra desbloquear na sua vez.'), findsOneWidget);
    expect(find.text('Desbloquear'), findsNothing);
  });

  testWidgets(
      'shows the extraLockedHint text instead of the button when the node '
      'is available but the hint is non-null', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SkillTreeScreen(
        title: 'Habilidades',
        unlockedNodeIds: const [],
        canUnlockNow: true,
        extraLockedHint: (nodeId) =>
            nodeId == 'ember_mastery' ? 'Faltam 7 turnos.' : null,
        onUnlock: (_) async => throw StateError('should not be called'),
      ),
    ));
    await tester.pump();

    await tester.tap(find.text('Maestria da Brasa'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Faltam 7 turnos.'), findsOneWidget);
    expect(find.text('Desbloquear'), findsNothing);
  });
}
