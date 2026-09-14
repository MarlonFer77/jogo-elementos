import 'package:battle_engine/battle_engine.dart';
import 'package:test/test.dart';

void main() {
  group('ElementUnlocks', () {
    test('has exactly one entry per built-in element', () {
      expect(ElementUnlocks.all.length, equals(Elements.all.length));
      final elementIds = ElementUnlocks.all.map((u) => u.elementId).toSet();
      expect(elementIds, equals(Elements.all.map((e) => e.id).toSet()));
    });

    test('all built-in unlocks have unique ids', () {
      final ids = ElementUnlocks.all.map((u) => u.id).toSet();
      expect(ids.length, equals(ElementUnlocks.all.length));
    });
  });
}
