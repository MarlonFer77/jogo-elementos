import 'package:app/game_presentation/pixel_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the label and reflects typed text in the controller',
      (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PixelTextField(controller: controller, label: 'Seu nome'),
      ),
    ));

    expect(find.text('Seu nome'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'ana');

    expect(controller.text, 'ana');
  });
}
