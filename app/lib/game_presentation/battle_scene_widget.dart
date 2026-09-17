import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game_domain/attack_event.dart';
import '../game_domain/battle_scene_view.dart';
import '../game_domain/element_catalog.dart';
import 'battle_hud_widget.dart';
import 'battle_scene_game.dart';

/// Hospeda um [BattleSceneGame] (arena + personagens, Flame) com um
/// [BattleHudWidget] (HP no topo, Flutter puro) sobreposto — numa área de
/// altura fixa no topo de uma tela de batalha. O jogo é criado uma única
/// vez por instância deste widget e recebe [view] via `updateView` a cada
/// rebuild.
class BattleSceneWidget extends StatefulWidget {
  const BattleSceneWidget({
    super.key,
    required this.view,
    this.onAttackComplete,
    this.height = 260,
  });

  final BattleSceneView view;
  final VoidCallback? onAttackComplete;
  final double height;

  @override
  State<BattleSceneWidget> createState() => _BattleSceneWidgetState();
}

class _BattleSceneWidgetState extends State<BattleSceneWidget> {
  final BattleSceneGame _game = BattleSceneGame();
  late BattleSceneView _hudView;
  AttackEvent? _activeAttack;
  bool _impactSeen = false;

  @override
  void initState() {
    super.initState();
    _hudView = widget.view;
    _activeAttack = widget.view.lastAttack;
    _game.onAttackImpact = _onImpact;
    _game.onAttackComplete = _onComplete;
    _game.updateView(widget.view);
  }

  @override
  void didUpdateWidget(covariant BattleSceneWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final attack = widget.view.lastAttack;
    if (attack == null) {
      _activeAttack = null;
      _hudView = widget.view;
    } else if (attack.sequenceId != oldWidget.view.lastAttack?.sequenceId) {
      // Hold only the presentation snapshot, never the authoritative state.
      _activeAttack = attack;
      _impactSeen = false;
    } else if (_activeAttack == null || _impactSeen) {
      _hudView = widget.view;
    }
    _game.updateView(widget.view);
  }

  void _onImpact(AttackEvent event) {
    if (!mounted || event.sequenceId != _activeAttack?.sequenceId) return;
    setState(() {
      _impactSeen = true;
      _hudView = widget.view;
    });
  }

  void _onComplete(AttackEvent event) {
    if (!mounted || event.sequenceId != _activeAttack?.sequenceId) return;
    setState(() {
      _activeAttack = null;
      _hudView = widget.view;
    });
    widget.onAttackComplete?.call();
  }

  Widget _attackCaption(AttackEvent attack) {
    final names = const ElementCatalog()
        .all()
        .where((element) => attack.elementIds.contains(element.id))
        .map((element) => element.name)
        .join(' + ');
    final name = attack.comboName ?? (names.isEmpty ? 'Ataque' : names);
    final actor = attack.attackerIsLeft
        ? widget.view.leftLabel
        : widget.view.rightLabel;
    final channeling =
        attack.comboName != null || attack.elementIds.length != 1;
    final result = !_impactSeen
        ? 'Preparando ataque…'
        : attack.damage > 0
        ? '${attack.damage} de dano'
        : 'Sem dano';
    return IgnorePointer(
      child: Semantics(
        liveRegion: true,
        child: Container(
          key: const ValueKey('attack-caption'),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F2DA),
            border: Border.all(color: const Color(0xFF253843), width: 2),
          ),
          child: Text(
            _impactSeen
                ? '$name · $result'
                : channeling
                ? 'Canalizando · $name'
                : '$actor · $name',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: Stack(
        children: [
          Positioned.fill(child: GameWidget(game: _game)),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: BattleHudWidget(
              view: _hudView,
              actingIsLeft: _activeAttack?.attackerIsLeft,
            ),
          ),
          if (_activeAttack != null)
            Positioned(
              left: 8,
              right: 8,
              bottom: 4,
              child: _attackCaption(_activeAttack!),
            ),
        ],
      ),
    );
  }
}
