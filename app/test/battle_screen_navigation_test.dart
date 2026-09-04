import 'package:app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('tapping the battle icon opens the demo battle screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(const GameApp());

    await tester.tap(find.byIcon(Icons.sports_kabaddi));
    // Not pumpAndSettle: Flame's game loop keeps scheduling frames, so
    // "settled" never happens. A couple of bounded pumps is enough to let
    // the navigation transition finish.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Batalha (demo)'), findsOneWidget);
  });
}
