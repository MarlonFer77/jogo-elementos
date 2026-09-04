import 'package:battle_engine/battle_engine.dart';
import 'package:test/test.dart';

void main() {
  group('CombinationModifier', () {
    test('two modifiers with the same id are equal', () {
      final a = CombinationModifier(
        id: 'x',
        name: 'X',
        description: 'a',
        apply: (e) => e,
      );
      final b = CombinationModifier(
        id: 'x',
        name: 'Outro nome',
        description: 'b',
        apply: (e) => e,
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('CombinationModifiers', () {
    test('all built-in modifiers have unique ids', () {
      final ids = CombinationModifiers.all.map((m) => m.id).toSet();
      expect(ids.length, equals(CombinationModifiers.all.length));
    });

    test('propagation increases area and leaves duration untouched', () {
      const effect = FieldEffect(
        id: 'x',
        name: 'X',
        description: 'd',
        area: 1,
        duration: 3,
      );
      final result = CombinationModifiers.propagation.apply(effect);
      expect(result.area, equals(3));
      expect(result.duration, equals(3));
    });

    test('volatility reduces duration by 1 down to a floor of 0', () {
      const effect = FieldEffect(
        id: 'x',
        name: 'X',
        description: 'd',
        duration: 1,
      );
      final result = CombinationModifiers.volatility.apply(effect);
      expect(result.duration, equals(0));

      final resultAgain = CombinationModifiers.volatility.apply(result);
      expect(resultAgain.duration, equals(0));
    });

    test('volatility is a no-op on a permanent (null duration) effect', () {
      const effect = FieldEffect(id: 'x', name: 'X', description: 'd');
      final result = CombinationModifiers.volatility.apply(effect);
      expect(result.duration, isNull);
    });

    test('modifiers compose when applied in sequence', () {
      const effect = FieldEffect(
        id: 'x',
        name: 'X',
        description: 'd',
        duration: 2,
      );
      var result = CombinationModifiers.propagation.apply(effect);
      result = CombinationModifiers.volatility.apply(result);

      expect(result.area, equals(3));
      expect(result.duration, equals(1));
    });
  });
}
