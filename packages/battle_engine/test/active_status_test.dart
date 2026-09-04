import 'package:battle_engine/battle_engine.dart';
import 'package:test/test.dart';

void main() {
  group('ActiveStatus', () {
    test('rejects a negative duration', () {
      expect(
        () => ActiveStatus(effect: StatusEffects.burn, turnsRemaining: -1),
        throwsArgumentError,
      );
    });

    test('a permanent status (null duration) is never expired', () {
      final status = ActiveStatus(effect: StatusEffects.shield);
      expect(status.isExpired, isFalse);
      expect(status.tick().turnsRemaining, isNull);
    });

    test('tick decrements the remaining duration by 1', () {
      final status =
          ActiveStatus(effect: StatusEffects.burn, turnsRemaining: 2);
      final ticked = status.tick();
      expect(ticked.turnsRemaining, equals(1));
      expect(ticked.isExpired, isFalse);
    });

    test('a status reaching 0 turns remaining is expired', () {
      final status =
          ActiveStatus(effect: StatusEffects.burn, turnsRemaining: 1);
      final ticked = status.tick();
      expect(ticked.turnsRemaining, equals(0));
      expect(ticked.isExpired, isTrue);
    });

    test('defaults damagePerTick to 0', () {
      final status = ActiveStatus(effect: StatusEffects.burn);
      expect(status.damagePerTick, equals(0));
    });

    test('rejects a negative damagePerTick', () {
      expect(
        () => ActiveStatus(effect: StatusEffects.burn, damagePerTick: -1),
        throwsArgumentError,
      );
    });

    test('tick preserves damagePerTick', () {
      final status = ActiveStatus(
        effect: StatusEffects.burn,
        turnsRemaining: 2,
        damagePerTick: 8,
      );
      final ticked = status.tick();
      expect(ticked.damagePerTick, equals(8));
    });
  });
}
