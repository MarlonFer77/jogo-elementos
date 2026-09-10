import 'package:app/game_presentation/pixel_page_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('pushes the built widget onto the navigator', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () {
            Navigator.of(context).push(
              pixelSlideRoute((_) => const Text('tela nova')),
            );
          },
          child: const Text('abrir'),
        ),
      ),
    ));

    await tester.tap(find.text('abrir'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('tela nova'), findsOneWidget);
  });
}
