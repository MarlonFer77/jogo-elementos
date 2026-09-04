import 'package:flame/components.dart';
import 'package:flame/game.dart';

import '../game_domain/battle_view.dart';

/// Flame game that renders a [BattleView]. Pure presentation — no battle
/// rules live here; the state to render is handed in from Game Domain.
class BattleGame extends FlameGame {
  final BattleView view;

  BattleGame({required this.view});

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    add(TextComponent(text: view.playerAName, position: Vector2(20, 20)));
    add(TextComponent(text: view.playerBName, position: Vector2(220, 20)));
    add(
      TextComponent(
        text: 'Turno: ${view.currentTurnName}',
        position: Vector2(20, 60),
      ),
    );

    var y = 100.0;
    for (final effectName in view.activeFieldEffectNames) {
      add(TextComponent(text: '• $effectName', position: Vector2(20, y)));
      y += 30;
    }
  }
}
