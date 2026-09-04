import 'package:battle_engine/battle_engine.dart';
import 'package:test/test.dart';

void main() {
  group('FieldEffect', () {
    test('two effects with the same id are equal', () {
      const a = FieldEffect(id: 'lava', name: 'Lava', description: 'x');
      const b = FieldEffect(id: 'lava', name: 'Outro nome', description: 'y');
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('ElementCombination.result exposes its data as a FieldEffect', () {
      final combo = defaultCombinationBook.resolve(
        [Elements.fire, Elements.wind],
      )!;
      expect(combo.result.id, equals(combo.resultId));
      expect(combo.result.name, equals(combo.resultName));
      expect(combo.result.description, equals(combo.description));
    });

    test('defaults to area 1 and no duration (permanent)', () {
      const effect = FieldEffect(id: 'x', name: 'X', description: 'd');
      expect(effect.area, equals(1));
      expect(effect.duration, isNull);
    });

    test('copyWith changes only the given fields', () {
      const effect = FieldEffect(
        id: 'x',
        name: 'X',
        description: 'd',
        area: 2,
        duration: 3,
      );
      final next = effect.copyWith(area: 5);
      expect(next.area, equals(5));
      expect(next.duration, equals(3));
      expect(next.id, equals('x'));
    });

    test('defaults damage to 0', () {
      const effect = FieldEffect(id: 'x', name: 'X', description: 'd');
      expect(effect.damage, equals(0));
    });

    test('copyWith can change damage', () {
      const effect = FieldEffect(id: 'x', name: 'X', description: 'd');
      final next = effect.copyWith(damage: 20);
      expect(next.damage, equals(20));
    });
  });
}
