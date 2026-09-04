import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game_domain/demo_battle.dart';
import '../game_presentation/battle_game.dart';

/// Hosts the Flame [BattleGame] inside a normal Flutter screen. Renders a
/// hardcoded demo battle for now — real battle screens (matchmaking,
/// player actions) come with the multiplayer/modo treino tasks.
class BattleScreen extends StatelessWidget {
  const BattleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Batalha (demo)')),
      body: GameWidget(game: BattleGame(view: DemoBattle.start())),
    );
  }
}
