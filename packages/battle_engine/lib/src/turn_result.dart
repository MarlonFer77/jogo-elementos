import 'battle_state.dart';
import 'element_combination.dart';

/// Outcome of resolving one [TurnAction]: the resulting [BattleState] and,
/// if the played elements matched a known combination, which one triggered.
class TurnResult {
  final BattleState state;
  final ElementCombination? triggeredCombination;

  const TurnResult({required this.state, this.triggeredCombination});
}
