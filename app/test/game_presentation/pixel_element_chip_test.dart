import 'package:app/game_presentation/pixel_element_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the label and calls onTap when tapped', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PixelElementChip(
          label: '🔥 Fogo',
          selected: false,
          onTap: () => tapped = true,
        ),
      ),
    ));

    expect(find.text('🔥 Fogo'), findsOneWidget);

    await tester.tap(find.text('🔥 Fogo'));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('does not throw and stays inert when onTap is null',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: PixelElementChip(label: '🔥 Fogo', selected: false, onTap: null),
      ),
    ));

    expect(find.text('🔥 Fogo'), findsOneWidget);

    await tester.tap(find.text('🔥 Fogo'));
    await tester.pump();
  });
}
