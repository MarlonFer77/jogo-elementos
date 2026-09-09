import 'package:app/game_presentation/pixel_menu_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the label and calls onPressed when tapped',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PixelMenuButton(
          label: 'MODO TREINO',
          onPressed: () => tapped = true,
        ),
      ),
    ));

    expect(find.text('MODO TREINO'), findsOneWidget);

    await tester.tap(find.text('MODO TREINO'));
    await tester.pump();

    expect(tapped, isTrue);
  });
}
