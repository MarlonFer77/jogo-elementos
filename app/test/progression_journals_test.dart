import 'package:app/game_domain/discovery_catalog.dart';
import 'package:app/game_domain/skill_tree_catalog.dart';
import 'package:app/ui/discovery_book_screen.dart';
import 'package:app/ui/skill_tree_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  List<DiscoveryEntry> entries() => const DiscoveryCatalog().entries(
    discoveredIds: ['ignited_storm', 'purifying_water'],
    learnedIds: ['ignited_storm', 'purifying_water'],
    equippedIds: [],
    unavailableReason: (_) => null,
  );

  test(
    'roles use real effects and build identity ignores starter elements',
    () {
      expect(
        entries()
            .firstWhere((e) => e.id == 'purifying_water')
            .matches(role: 'Suporte'),
        isTrue,
      );
      expect(
        entries()
            .firstWhere((e) => e.id == 'purifying_water')
            .matches(role: 'Ataque'),
        isFalse,
      );
      expect(
        entries().firstWhere((e) => e.id == 'ignited_storm').roles,
        containsAll(['Ataque', 'Desgaste']),
      );
      expect(
        skillBuildIdentity(['unlock_fire', 'unlock_water']),
        'Explorador · escolha seu estilo',
      );
      expect(
        skillBuildIdentity([
          'ember_mastery',
          'wildfire_path',
          'guard_training',
        ]),
        'Estilo: Fogo',
      );
    },
  );

  for (final size in [const Size(320, 568), const Size(740, 360)]) {
    testWidgets('journal filters, temporary goal and keyboard fit $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      var purchases = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: SkillTreeScreen(
            title: 'Árvore',
            unlockedNodeIds: const ['unlock_fire', 'unlock_water'],
            canUnlockNow: true,
            onUnlock: (_) async {
              purchases++;
              return null;
            },
            extraLockedHint: (id) =>
                id == 'unstable_core_training' ? 'Falta 1 ponto.' : null,
          ),
        ),
      );
      final target = find.text('Caminho do Incêndio');
      await tester.ensureVisible(target);
      await tester.tap(target);
      await tester.pumpAndSettle();
      final mark = find.text('Marcar como objetivo');
      await tester.ensureVisible(mark);
      await tester.tap(mark);
      await tester.pumpAndSettle();
      expect(find.text('Objetivo: Caminho do Incêndio'), findsOneWidget);
      expect(purchases, 0);
      final branch = find.text('Precisão · 0/2');
      await tester.ensureVisible(branch);
      await tester.tap(branch);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Somente disponíveis'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Nenhuma habilidade disponível'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        MaterialApp(
          home: DiscoveryBookScreen(
            playerLabel: 'Jogador A',
            entries: entries,
            onManage: () async {},
          ),
        ),
      );
      await tester.tap(find.byTooltip('Filtrar descobertas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Suporte'));
      final results = find.text('Ver resultados');
      await tester.ensureVisible(results);
      await tester.tap(results);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('discovery-purifying_water')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('discovery-ignited_storm')),
        findsNothing,
      );
      expect(find.text('Lava'), findsNothing);
      tester.view.viewInsets = const FakeViewPadding(bottom: 220);
      await tester.pump();
      expect(find.byType(TextField).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
