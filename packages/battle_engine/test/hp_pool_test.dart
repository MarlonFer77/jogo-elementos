import 'package:battle_engine/battle_engine.dart';
import 'package:test/test.dart';

void main() {
  group('HpPool', () {
    test('isDefeated is false when current is above 0', () {
      const pool = HpPool(max: 100, current: 1);
      expect(pool.isDefeated, isFalse);
    });

    test('isDefeated is true when current is 0', () {
      const pool = HpPool(max: 100, current: 0);
      expect(pool.isDefeated, isTrue);
    });

    test('withDamage subtracts from current', () {
      const pool = HpPool(max: 100, current: 100);
      final next = pool.withDamage(30);
      expect(next.current, equals(70));
      expect(next.max, equals(100));
    });

    test('withDamage clamps current at 0, never negative', () {
      const pool = HpPool(max: 100, current: 10);
      final next = pool.withDamage(999);
      expect(next.current, equals(0));
    });

    test('withDamage rejects a negative amount', () {
      const pool = HpPool(max: 100, current: 100);
      expect(() => pool.withDamage(-1), throwsArgumentError);
    });

    test('withMaxIncreased raises both max and current', () {
      const pool = HpPool(max: 100, current: 60);
      final next = pool.withMaxIncreased(20);
      expect(next.max, equals(120));
      expect(next.current, equals(80));
    });

    test('withMaxIncreased rejects a negative amount', () {
      const pool = HpPool(max: 100, current: 100);
      expect(() => pool.withMaxIncreased(-1), throwsArgumentError);
    });
  });
}
