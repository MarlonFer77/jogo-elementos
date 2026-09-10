import 'package:app/game_presentation/skill_tree_layout.dart';
import 'package:app/game_presentation/skill_tree_node_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the name and icon, and calls onTap when tapped',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SkillTreeNodeWidget(
          name: 'Maestria da Brasa',
          icon: '🔥',
          state: SkillTreeNodeState.available,
          onTap: () => tapped = true,
        ),
      ),
    ));

    expect(find.text('Maestria da Brasa'), findsOneWidget);
    expect(find.text('🔥'), findsOneWidget);

    await tester.tap(find.text('Maestria da Brasa'));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('renders without throwing for every state', (tester) async {
    for (final state in SkillTreeNodeState.values) {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SkillTreeNodeWidget(
            name: 'Nó',
            icon: '🔥',
            state: state,
            onTap: () {},
          ),
        ),
      ));
      expect(find.text('Nó'), findsOneWidget);
    }
  });
}
