import 'package:app/game_presentation/pixel_outlined_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the given text', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: PixelOutlinedText('TESTE'))),
    );
    expect(find.text('TESTE'), findsOneWidget);
  });
}
