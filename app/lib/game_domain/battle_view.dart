import 'package:battle_engine/battle_engine.dart';

/// Read-only view of a [BattleState] for the presentation layer. Game
/// Presentation (Flame) never touches `battle_engine` types directly —
/// it renders a [BattleView].
class BattleView {
  final String playerAName;
  final String playerBName;
  final String currentTurnName;
  final List<String> activeFieldEffectNames;

  const BattleView({
    required this.playerAName,
    required this.playerBName,
    required this.currentTurnName,
    required this.activeFieldEffectNames,
  });

  factory BattleView.fromState(BattleState state) {
    return BattleView(
      playerAName: state.playerA.name,
      playerBName: state.playerB.name,
      currentTurnName: state.currentTurn.name,
      activeFieldEffectNames: state.activeFieldEffects
          .map((effect) => effect.name)
          .toList(),
    );
  }
}
