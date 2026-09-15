import 'package:app/game_domain/attack_catalog.dart';
import 'package:app/ui/attacks_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _storm = AttackOption(
  id: 'ignited_storm',
  name: 'Tempestade Ígnea',
  description: 'Fogo espalhado pelo vento; dano em área.',
  unlocked: true,
  equipped: false,
);
const _field = AttackOption(
  id: 'electrified_field',
  name: 'Campo Eletrocutado',
  description: 'Água carregada de eletricidade; choca quem entrar no campo.',
  unlocked: true,
  equipped: false,
);
const _lockedLava = AttackOption(
  id: 'lava',
  name: 'Lava',
  description: 'Terra fundida pelo fogo; terreno perigoso e persistente.',
  unlocked: false,
  equipped: false,
);

void main() {
  testWidgets('lists only unlocked attacks', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AttacksScreen(
        attacks: [_storm, _lockedLava],
        onSetEquipped: (_) async => null,
      ),
    ));
    await tester.pump();

    expect(find.text('Tempestade Ígnea'), findsOneWidget);
    expect(find.text('Lava'), findsNothing);
  });

  testWidgets('tapping a non-equipped attack with room equips it directly',
      (tester) async {
    List<String>? sentIds;
    await tester.pumpWidget(MaterialApp(
      home: AttacksScreen(
        attacks: [_storm],
        onSetEquipped: (ids) async {
          sentIds = ids;
          return null;
        },
      ),
    ));
    await tester.pump();

    await tester.tap(find.text('Tempestade Ígnea'));
    await tester.pump();

    expect(sentIds, ['ignited_storm']);
  });

  testWidgets(
      'tapping a non-equipped attack with 3 already equipped opens a swap '
      'picker', (tester) async {
    const equippedA = AttackOption(
      id: 'a',
      name: 'A',
      description: 'x',
      unlocked: true,
      equipped: true,
    );
    const equippedB = AttackOption(
      id: 'b',
      name: 'B',
      description: 'x',
      unlocked: true,
      equipped: true,
    );
    const equippedC = AttackOption(
      id: 'c',
      name: 'C',
      description: 'x',
      unlocked: true,
      equipped: true,
    );
    List<String>? sentIds;
    await tester.pumpWidget(MaterialApp(
      home: AttacksScreen(
        attacks: [equippedA, equippedB, equippedC, _storm],
        onSetEquipped: (ids) async {
          sentIds = ids;
          return null;
        },
      ),
    ));
    await tester.pump();

    await tester.tap(find.text('Tempestade Ígnea'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // O seletor de troca lista os 3 atualmente equipados.
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('C'), findsOneWidget);

    await tester.tap(find.text('B'));
    await tester.pump();

    expect(sentIds, containsAll(['a', 'c', 'ignited_storm']));
    expect(sentIds, isNot(contains('b')));
    expect(sentIds!.length, 3);
  });

  testWidgets('tapping an equipped attack offers to unequip it',
      (tester) async {
    const equipped = AttackOption(
      id: 'ignited_storm',
      name: 'Tempestade Ígnea',
      description: 'x',
      unlocked: true,
      equipped: true,
    );
    List<String>? sentIds;
    await tester.pumpWidget(MaterialApp(
      home: AttacksScreen(
        attacks: [equipped],
        onSetEquipped: (ids) async {
          sentIds = ids;
          return null;
        },
      ),
    ));
    await tester.pump();

    await tester.tap(find.text('Tempestade Ígnea'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Desequipar'));
    await tester.pump();

    expect(sentIds, isEmpty);
  });

  testWidgets(
      'highlightComboId opens the swap picker automatically when slots are '
      'full', (tester) async {
    const equippedA = AttackOption(
      id: 'a',
      name: 'A',
      description: 'x',
      unlocked: true,
      equipped: true,
    );
    const equippedB = AttackOption(
      id: 'b',
      name: 'B',
      description: 'x',
      unlocked: true,
      equipped: true,
    );
    const equippedC = AttackOption(
      id: 'c',
      name: 'C',
      description: 'x',
      unlocked: true,
      equipped: true,
    );
    await tester.pumpWidget(MaterialApp(
      home: AttacksScreen(
        attacks: [equippedA, equippedB, equippedC, _storm],
        onSetEquipped: (_) async => null,
        highlightComboId: 'ignited_storm',
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.textContaining('substituir por Tempestade Ígnea'),
      findsOneWidget,
    );
  });
}
