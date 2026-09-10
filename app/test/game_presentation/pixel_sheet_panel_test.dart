import 'package:app/game_presentation/pixel_sheet_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders its child', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: PixelSheetPanel(child: Text('conteúdo'))),
    ));
    expect(find.text('conteúdo'), findsOneWidget);
  });
}
