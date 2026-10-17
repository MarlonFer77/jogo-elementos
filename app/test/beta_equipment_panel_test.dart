import 'package:app/game_domain/beta_session.dart';
import 'package:app/game_domain/cosmetics.dart';
import 'package:app/ui/beta_build_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final size in [const Size(320, 568), const Size(568, 320)]) {
    testWidgets('active equipment readable without mutations at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final run =
          BetaSession(
              loadout: const BetaLoadout(
                sword: ShopUpgrade.spin,
                dodge: ShopUpgrade.somersault,
                weapon: ShopUpgrade.excalibur,
                cloak: ShopUpgrade.mercerus,
                armor: ShopUpgrade.perseus,
              ),
            )
            ..start()
            ..pause();
      var changes = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BetaBuildPanel(
              run: run,
              outfit: HeroOutfit.angel,
              onChanged: () => changes++,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Equipamento'));
      await tester.pumpAndSettle();
      expect(
        find.text('Ataque da relíquia: +4 · Agilidade: +10'),
        findsOneWidget,
      );
      for (final label in [
        'Anjo da Aurora',
        'Corte Giratório',
        'Mortal do Viajante',
        'Excalibur',
        'Capa de Mercerus',
        'Peitoral de Perseu',
      ]) {
        await tester.scrollUntilVisible(
          find.text(label),
          75,
          scrollable: find.descendant(
            of: find.byKey(const ValueKey('beta-equipment')),
            matching: find.byType(Scrollable),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(label).hitTestable(), findsOneWidget);
      }
      expect(changes, 0);
      expect(run.phase, BetaPhase.paused);
      expect(run.skillPoints, 1);
      expect(run.hp, 100);
      expect(run.loadout.perseus, true);
      expect(tester.takeException(), isNull);
    });
  }
}
