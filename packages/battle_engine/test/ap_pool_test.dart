import 'package:battle_engine/battle_engine.dart';
import 'package:test/test.dart';

void main() {
  group('canAfford', () {
    test('true when current is greater than or equal to amount', () {
      const pool = ApPool(max: 5, current: 3);
      expect(pool.canAfford(3), isTrue);
      expect(pool.canAfford(2), isTrue);
    });

    test('false when current is less than amount', () {
      const pool = ApPool(max: 5, current: 2);
      expect(pool.canAfford(3), isFalse);
    });
  });

  group('withRegenerated', () {
    test('increments current by 1', () {
      const pool = ApPool(max: 5, current: 2);
      expect(pool.withRegenerated().current, equals(3));
    });

    test('clamps at max', () {
      const pool = ApPool(max: 5, current: 5);
      expect(pool.withRegenerated().current, equals(5));
    });
  });

  group('withSpent', () {
    test('subtracts amount from current', () {
      const pool = ApPool(max: 5, current: 4);
      expect(pool.withSpent(3).current, equals(1));
    });

    test('throws for a negative amount', () {
      const pool = ApPool(max: 5, current: 4);
      expect(() => pool.withSpent(-1), throwsArgumentError);
    });

    test('throws when amount exceeds current', () {
      const pool = ApPool(max: 5, current: 2);
      expect(() => pool.withSpent(3), throwsArgumentError);
    });
  });
}
