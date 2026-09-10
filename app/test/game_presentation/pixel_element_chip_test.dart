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

  testWidgets(
      'shows a pressed-in offset while held down, and releases it back',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PixelElementChip(
          label: '🔥 Fogo',
          selected: false,
          onTap: () {},
        ),
      ),
    ));

    final gesture =
        await tester.startGesture(tester.getCenter(find.text('🔥 Fogo')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    final pressed =
        tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
    expect(pressed.transform, Matrix4.translationValues(3, 3, 0));

    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    final released =
        tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
    expect(released.transform, Matrix4.translationValues(0, 0, 0));
  });
}
