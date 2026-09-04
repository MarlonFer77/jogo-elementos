import 'package:battle_engine/battle_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Element', () {
    test('two elements with the same id are equal', () {
      const a = Element(id: 'fire', name: 'Fogo', symbol: '🔥');
      const b = Element(id: 'fire', name: 'Fogo (outro nome)', symbol: '🔥');
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('elements with different ids are not equal', () {
      expect(Elements.fire, isNot(equals(Elements.water)));
    });

    test('Elements.all contains every built-in element without duplicates',
        () {
      final ids = Elements.all.map((e) => e.id).toSet();
      expect(ids.length, equals(Elements.all.length));
      expect(ids, contains('fire'));
      expect(ids, contains('poison'));
    });
  });
}
