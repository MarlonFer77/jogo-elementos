import 'package:app/game_domain/discovery_catalog.dart';
import 'package:app/ui/discovery_book_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const catalog = DiscoveryCatalog();
  test(
    'book ignores stale IDs and separates shared discovery from personal learning',
    () {
      final entries = catalog.entries(
        discoveredIds: ['ignited_storm', 'ignited_storm', 'removed'],
        learnedIds: [],
        equippedIds: ['ignited_storm'],
        unavailableReason: (_) => throw StateError('not learned'),
      );
      expect(entries, hasLength(1));
      expect(entries.single.learned, false);
      expect(entries.single.equipped, false);
      expect(entries.single.elements, containsAll(['fire', 'wind']));
    },
  );
  test(
    'search is accent-insensitive and combines element, AP and equipped filters',
    () {
      final entry = catalog
          .entries(
            discoveredIds: ['ignited_storm'],
            learnedIds: ['ignited_storm'],
            equippedIds: ['ignited_storm'],
            unavailableReason: (_) => 'Faltam 2 AP',
          )
          .single;
      expect(
        entry.matches(
          query: '  IGNEA ',
          element: 'fire',
          cost: 3,
          equippedOnly: true,
        ),
        true,
      );
      expect(entry.matches(query: 'queimadura'), true);
      expect(entry.matches(element: 'water'), false);
      expect(entry.matches(cost: 5), false);
      expect(entry.unavailableReason, 'Faltam 2 AP');
    },
  );
  for (final size in [const Size(360, 800), const Size(800, 360)]) {
    testWidgets(
      'book protects hidden recipes, filters and refreshes equipment at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var equipped = false;
        await tester.pumpWidget(
          MaterialApp(
            home: DiscoveryBookScreen(
              playerLabel: 'Jogador A',
              entries: () => catalog.entries(
                discoveredIds: ['ignited_storm'],
                learnedIds: ['ignited_storm'],
                equippedIds: equipped ? ['ignited_storm'] : [],
                unavailableReason: (_) => null,
              ),
              onManage: () async {
                equipped = true;
              },
            ),
          ),
        );
        expect(find.text('Lava'), findsNothing);
        expect(find.byKey(const ValueKey('discovery-lava')), findsNothing);
        final tile = find.byKey(const ValueKey('discovery-ignited_storm'));
        await tester.ensureVisible(tile);
        await tester.tap(find.text('Tempestade Ígnea'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Receita:'), findsOneWidget);
        final search = find.byType(TextField);
        await tester.ensureVisible(search);
        await tester.enterText(search, 'lava');
        await tester.pump();
        expect(
          find.text('Nenhuma descoberta corresponde aos filtros.'),
          findsOneWidget,
        );
        expect(find.text('Lava'), findsNothing);
        await tester.enterText(search, '');
        await tester.pump();
        final manage = find.text('Gerenciar habilidades');
        await tester.ensureVisible(manage);
        await tester.tap(manage);
        await tester.pumpAndSettle();
        expect(equipped, true);
        expect(find.textContaining('1/3 equipadas'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
