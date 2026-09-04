/// An immutable HP pool: how much a combatant can take (`max`) and how
/// much they have left (`current`). `current` never goes below 0 or above
/// `max`. There is no healing in this engine yet — both mutating methods
/// reject a negative `amount`.
class HpPool {
  final int max;
  final int current;

  const HpPool({required this.max, required this.current});

  bool get isDefeated => current <= 0;

  /// Returns a new pool with [amount] subtracted from `current`, clamped
  /// at 0.
  HpPool withDamage(int amount) {
    if (amount < 0) {
      throw ArgumentError.value(amount, 'amount', 'must not be negative');
    }
    final next = current - amount;
    return HpPool(max: max, current: next < 0 ? 0 : next);
  }

  /// Returns a new pool with [amount] added to both `max` and `current` —
  /// used when a mid-battle bonus (e.g. a Skill Tree node) raises the
  /// ceiling; the combatant gets tougher right now, not just later.
  HpPool withMaxIncreased(int amount) {
    if (amount < 0) {
      throw ArgumentError.value(amount, 'amount', 'must not be negative');
    }
    return HpPool(max: max + amount, current: current + amount);
  }
}
