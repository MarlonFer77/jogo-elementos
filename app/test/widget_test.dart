import 'package:flutter_test/flutter_test.dart';

import 'package:app/main.dart';
import 'package:app/game_domain/element_catalog.dart';

void main() {
  testWidgets('home screen lists every built-in element from the Battle '
      'Engine', (WidgetTester tester) async {
    await tester.pumpWidget(const GameApp());

    for (final element in const ElementCatalog().all()) {
      expect(find.text(element.name), findsOneWidget);
    }
  });
}
