/// An immutable AP (action point) pool: how much a combatant can hold
/// (`max`) and how much they currently have (`current`). Used to gate
/// combining 2-3 elements in one turn — see [TurnEngine.playTurn].
/// `current` never goes below 0 or above `max`.
class ApPool {
  final int max;
  final int current;

  const ApPool({required this.max, required this.current});

  bool canAfford(int amount) => current >= amount;

  /// Returns a new pool with `current` incremented by 1, clamped at `max`.
  ApPool withRegenerated() {
    final next = current + 1;
    return ApPool(max: max, current: next > max ? max : next);
  }

  /// Returns a new pool with `amount` subtracted from `current`. Callers
  /// must check [canAfford] first — throws if `amount` is negative or
  /// exceeds `current`.
  ApPool withSpent(int amount) {
    if (amount < 0) {
      throw ArgumentError.value(amount, 'amount', 'must not be negative');
    }
    if (amount > current) {
      throw ArgumentError.value(amount, 'amount', 'exceeds current AP');
    }
    return ApPool(max: max, current: current - amount);
  }
}
