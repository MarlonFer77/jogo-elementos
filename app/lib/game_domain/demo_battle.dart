import 'package:battle_engine/battle_engine.dart';

import 'battle_view.dart';

/// A small hardcoded battle used to prove the Flame integration renders
/// real Battle Engine state (including a triggered combination). Real
/// battle orchestration — creating a match, player actions — is a later
/// task (multiplayer / modo treino).
class DemoBattle {
  static BattleView start() {
    const playerA = Combatant(id: 'a', name: 'Ana');
    const playerB = Combatant(id: 'b', name: 'Beto');
    final state = BattleState.start(playerA: playerA, playerB: playerB);

    final engine = TurnEngine(defaultCombinationBook);
    final result = engine.playTurn(
      state,
      TurnAction(actor: playerA, elements: [Elements.fire, Elements.wind]),
    );

    return BattleView.fromState(result.state);
  }
}
