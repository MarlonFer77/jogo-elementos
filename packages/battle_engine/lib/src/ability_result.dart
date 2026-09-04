import 'ability_effect.dart';
import 'battle_state.dart';
import 'element_combination.dart';

/// Outcome of resolving one [Ability] use: the resulting [BattleState], the
/// accumulated [AbilityEffect] from its mutations, and which combination (if
/// any) the base elements triggered.
class AbilityResult {
  final BattleState state;
  final AbilityEffect effect;
  final ElementCombination? triggeredCombination;

  const AbilityResult({
    required this.state,
    required this.effect,
    this.triggeredCombination,
  });
}
