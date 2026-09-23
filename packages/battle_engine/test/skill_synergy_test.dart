import 'package:battle_engine/battle_engine.dart';
import 'package:test/test.dart';

void main() {
  test(
    'propagation strengthens DOT; volatility trades duration for one bonus',
    () {
      final base = defaultCombinationBook.resolve([
        Elements.fire,
        Elements.poison,
      ])!.result;
      final spread = CombinationModifiers.propagation.apply(base);
      expect(spread.statusesToApply.first.status.damagePerTick, 4);
      expect(base.statusesToApply.first.status.damagePerTick, 3);
      final burst = CombinationModifiers.volatility.apply(spread);
      expect(burst.damage, base.damage + 4);
      expect(burst.statusesToApply.map((s) => s.status.turnsRemaining), [1, 2]);
      final shield = defaultCombinationBook.resolve([
        Elements.earth,
        Elements.light,
      ])!.result;
      expect(
        CombinationModifiers.volatility.apply(shield).damage,
        shield.damage,
      );
      expect(
        CombinationModifiers.propagation
            .apply(shield)
            .statusesToApply
            .first
            .status
            .damagePerTick,
        0,
      );
    },
  );
}
