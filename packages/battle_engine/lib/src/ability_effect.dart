import 'field_effect.dart';
import 'targeted_status.dart';

/// The accumulated effect of resolving an [Ability]'s mutations, before it
/// is applied to a [BattleState].
///
/// [hitCount] and [critChanceBonus] are not consumed by anything yet — there
/// is no damage/crit system in the engine. They are carried as data for
/// whichever system implements that later, rather than being computed here.
class AbilityEffect {
  final List<TargetedStatus> statusesToApply;
  final FieldEffect? fieldEffect;
  final int hitCount;
  final double critChanceBonus;

  const AbilityEffect({
    this.statusesToApply = const [],
    this.fieldEffect,
    this.hitCount = 1,
    this.critChanceBonus = 0,
  });

  AbilityEffect copyWith({
    List<TargetedStatus>? statusesToApply,
    FieldEffect? fieldEffect,
    int? hitCount,
    double? critChanceBonus,
  }) {
    return AbilityEffect(
      statusesToApply: statusesToApply ?? this.statusesToApply,
      fieldEffect: fieldEffect ?? this.fieldEffect,
      hitCount: hitCount ?? this.hitCount,
      critChanceBonus: critChanceBonus ?? this.critChanceBonus,
    );
  }
}
