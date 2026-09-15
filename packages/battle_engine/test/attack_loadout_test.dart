import 'package:battle_engine/battle_engine.dart';
import 'package:test/test.dart';

void main() {
  group('AttackLoadout.isUnlocked/isEquipped', () {
    test('nothing is unlocked or equipped by default', () {
      final loadout = AttackLoadout();
      expect(loadout.isUnlocked('ignited_storm'), isFalse);
      expect(loadout.isEquipped('ignited_storm'), isFalse);
    });
  });

  group('AttackLoadout.withUnlocked', () {
    test('marks the combination as unlocked', () {
      final loadout = AttackLoadout().withUnlocked('ignited_storm');
      expect(loadout.isUnlocked('ignited_storm'), isTrue);
    });

    test('auto-equips when there is room (fewer than 3 equipped)', () {
      final loadout = AttackLoadout().withUnlocked('ignited_storm');
      expect(loadout.isEquipped('ignited_storm'), isTrue);
      expect(loadout.equippedCombinationIds, ['ignited_storm']);
    });

    test('does not auto-equip once 3 are already equipped', () {
      var loadout = AttackLoadout()
          .withUnlocked('a')
          .withUnlocked('b')
          .withUnlocked('c');
      expect(loadout.equippedCombinationIds, ['a', 'b', 'c']);

      loadout = loadout.withUnlocked('d');

      expect(loadout.isUnlocked('d'), isTrue);
      expect(loadout.isEquipped('d'), isFalse);
      expect(loadout.equippedCombinationIds, ['a', 'b', 'c']);
    });

    test('is a no-op if already unlocked', () {
      final once = AttackLoadout().withUnlocked('ignited_storm');
      final twice = once.withUnlocked('ignited_storm');
      expect(twice.unlockedCombinationIds, once.unlockedCombinationIds);
      expect(twice.equippedCombinationIds, once.equippedCombinationIds);
    });
  });

  group('AttackLoadout.withEquipped', () {
    test('replaces the equipped list', () {
      final loadout = AttackLoadout()
          .withUnlocked('a')
          .withUnlocked('b')
          .withUnlocked('c')
          .withUnlocked('d'); // d unlocked but not equipped (3 already full)

      final updated = loadout.withEquipped(['a', 'd']);

      expect(updated.equippedCombinationIds, ['a', 'd']);
      expect(updated.isEquipped('b'), isFalse);
      expect(updated.isEquipped('c'), isFalse);
    });

    test('throws if given more than 3 ids', () {
      final loadout = AttackLoadout()
          .withUnlocked('a')
          .withUnlocked('b')
          .withUnlocked('c')
          .withUnlocked('d');
      expect(
        () => loadout.withEquipped(['a', 'b', 'c', 'd']),
        throwsArgumentError,
      );
    });

    test('throws if an id is not unlocked yet', () {
      final loadout = AttackLoadout().withUnlocked('a');
      expect(
        () => loadout.withEquipped(['a', 'ghost']),
        throwsArgumentError,
      );
    });
  });
}
