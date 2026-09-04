import 'status_effect.dart';

/// An instance of a [StatusEffect] applied to a target. [turnsRemaining]
/// counts down by 1 on each [tick]; `null` means it lasts until removed
/// explicitly (e.g. a Shield consumed on hit, not by turn count).
/// [damagePerTick] is how much damage this instance deals every time it
/// ticks (0 for statuses that don't damage, e.g. Shield) — set per
/// instance, not fixed by [StatusEffect] kind, so a stronger source could
/// apply a harsher Burn than a weaker one.
class ActiveStatus {
  final StatusEffect effect;
  final int? turnsRemaining;
  final int damagePerTick;

  ActiveStatus({
    required this.effect,
    this.turnsRemaining,
    this.damagePerTick = 0,
  }) {
    if (turnsRemaining != null && turnsRemaining! < 0) {
      throw ArgumentError.value(
        turnsRemaining,
        'turnsRemaining',
        'must be null or 0 or greater',
      );
    }
    if (damagePerTick < 0) {
      throw ArgumentError.value(
        damagePerTick,
        'damagePerTick',
        'must not be negative',
      );
    }
  }

  bool get isExpired => turnsRemaining != null && turnsRemaining! <= 0;

  /// Returns a copy with [turnsRemaining] decremented by 1, or the same
  /// instance if it has no duration (permanent until removed).
  ActiveStatus tick() {
    if (turnsRemaining == null) return this;
    return ActiveStatus(
      effect: effect,
      turnsRemaining: turnsRemaining! - 1,
      damagePerTick: damagePerTick,
    );
  }
}
