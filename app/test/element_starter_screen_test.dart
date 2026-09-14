import 'package:app/game_presentation/pixel_menu_button.dart';
import 'package:app/ui/element_starter_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the player label in the title', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ElementStarterScreen(
        playerLabel: 'Jogador A',
        onConfirm: (_) {},
      ),
    ));
    await tester.pump();

    expect(find.textContaining('Jogador A'), findsWidgets);
  });

  testWidgets('Confirmar is disabled with 0 or 1 elements selected, '
      'enabled with exactly 2', (tester) async {
    List<String>? confirmed;
    await tester.pumpWidget(MaterialApp(
      home: ElementStarterScreen(
        playerLabel: 'Jogador A',
        onConfirm: (ids) => confirmed = ids,
      ),
    ));
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

  testWidgets('selecting a 3rd element does not replace the first 2',
      (tester) async {
    List<String>? confirmed;
    await tester.pumpWidget(MaterialApp(
      home: ElementStarterScreen(
        playerLabel: 'Jogador A',
        onConfirm: (ids) => confirmed = ids,
      ),
    ));
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
