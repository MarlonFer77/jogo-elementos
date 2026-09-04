import 'package:battle_engine/battle_engine.dart';
import 'package:test/test.dart';

void main() {
  group('MaxHpBonus', () {
    test('two bonuses with the same id are equal', () {
      const a = MaxHpBonus(id: 'x', name: 'X', description: 'a', bonus: 10);
      const b = MaxHpBonus(id: 'x', name: 'Outro nome', description: 'b', bonus: 99);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('MaxHpBonuses', () {
    test('vitality grants 20 HP', () {
      expect(MaxHpBonuses.vitality.bonus, equals(20));
    });

    test('all built-in bonuses have unique ids', () {
      final ids = MaxHpBonuses.all.map((b) => b.id).toSet();
      expect(ids.length, equals(MaxHpBonuses.all.length));
    });
  });
}
