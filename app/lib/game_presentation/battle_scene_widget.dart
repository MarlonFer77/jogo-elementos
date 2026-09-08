import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game_domain/battle_scene_view.dart';
import 'battle_scene_game.dart';

/// Hospeda um [BattleSceneGame] numa área de altura fixa no topo de uma
/// tela de batalha. O jogo é criado uma única vez por instância deste
/// widget e recebe [view] via `updateView` a cada rebuild — não a cada
/// frame do jogo, só quando a tela que o contém já ia re-renderizar de
/// qualquer forma (nova jogada, poll do Multiplayer, etc.).
class BattleSceneWidget extends StatefulWidget {
  const BattleSceneWidget({super.key, required this.view});

  final BattleSceneView view;

  @override
  State<BattleSceneWidget> createState() => _BattleSceneWidgetState();
}

class _BattleSceneWidgetState extends State<BattleSceneWidget> {
  final BattleSceneGame _game = BattleSceneGame();

  @override
  void initState() {
    super.initState();
    _game.updateView(widget.view);
  }

  @override
  void didUpdateWidget(covariant BattleSceneWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _game.updateView(widget.view);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: GameWidget(game: _game),
    );
  }
}
