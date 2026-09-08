import 'package:flame/components.dart';
import 'package:flame/game.dart';

import '../game_domain/attack_event.dart';
import '../game_domain/battle_scene_view.dart';
import 'attack_sequence_player.dart';
import 'battle_character_component.dart';

/// Se [currentHp] deve ser tratado como dano em relação a [previousHp].
/// `previousHp == null` (primeira leitura, ainda sem baseline) nunca conta
/// como dano. Pura e sem efeito colateral — fica fora de qualquer
/// componente do Flame para ser testável sem o game loop.
bool didTakeDamage({required int? previousHp, required int currentHp}) {
  return previousHp != null && currentHp < previousHp;
}

/// Jogo Flame que renderiza um [BattleSceneView]: um fundo estático mais
/// dois personagens genéricos (um por lado) com barra de HP, indicador de
/// vez, e um flash+shake breve quando o HP de um lado cai. Apresentação
/// pura — nenhuma regra de batalha mora aqui; o estado a renderizar vem de
/// fora via [updateView].
class BattleSceneGame extends FlameGame {
  BattleCharacterComponent? _left;
  BattleCharacterComponent? _right;

  int? _lastLeftHp;
  int? _lastRightHp;
  int? _lastPlayedSequenceId;
  AttackSequencePlayer? _activeSequence;
  BattleSceneView? _pendingView;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    final background = await loadSprite('battlefield_bg.jpg');
    add(SpriteComponent(sprite: background, size: size)..priority = -1);

    final left = BattleCharacterComponent(
      side: BattleSide.left,
      position: Vector2(size.x * 0.25, size.y * 0.85),
    );
    final right = BattleCharacterComponent(
      side: BattleSide.right,
      position: Vector2(size.x * 0.75, size.y * 0.85),
    );
    add(left);
    add(right);
    _left = left;
    _right = right;

    final pending = _pendingView;
    if (pending != null) {
      _applyView(pending);
    }
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    for (final child in children.whereType<SpriteComponent>()) {
      child.size = size;
    }
  }

  /// Reflete [view] na cena: atualiza as duas barras de HP e o indicador
  /// de vez, e toca o efeito de dano no lado cujo HP acabou de cair em
  /// relação à última chamada. Seguro chamar antes do `onLoad` terminar
  /// (guarda a view pendente e aplica assim que os personagens existirem).
  void updateView(BattleSceneView view) {
    if (_left == null || _right == null) {
      _pendingView = view;
      return;
    }
    _applyView(view);
  }

  void _applyView(BattleSceneView view) {
    final left = _left!;
    final right = _right!;

    left.setHpFraction(view.leftMaxHp == 0 ? 0 : view.leftCurrentHp / view.leftMaxHp);
    right.setHpFraction(view.rightMaxHp == 0 ? 0 : view.rightCurrentHp / view.rightMaxHp);
    left.setActiveTurn(view.isLeftTurn);
    right.setActiveTurn(!view.isLeftTurn);

    final attack = view.lastAttack;
    if (attack != null && attack.sequenceId != _lastPlayedSequenceId) {
      _lastPlayedSequenceId = attack.sequenceId;
      _playAttackSequence(attack);
    } else if (didTakeDamage(previousHp: _lastLeftHp, currentHp: view.leftCurrentHp) ||
        didTakeDamage(previousHp: _lastRightHp, currentHp: view.rightCurrentHp)) {
      // Fallback defensivo: HP caiu mas nenhum AttackEvent chegou (não
      // deveria acontecer — só combinação causa dano, e toda combinação
      // vira AttackEvent nas telas). Mantém pelo menos o flash simples de
      // antes em vez de dano silencioso.
      if (didTakeDamage(previousHp: _lastLeftHp, currentHp: view.leftCurrentHp)) {
        left.playHitEffect();
      }
      if (didTakeDamage(previousHp: _lastRightHp, currentHp: view.rightCurrentHp)) {
        right.playHitEffect();
      }
    }

    _lastLeftHp = view.leftCurrentHp;
    _lastRightHp = view.rightCurrentHp;
  }

  void _playAttackSequence(AttackEvent event) {
    final left = _left!;
    final right = _right!;
    final attacker = event.attackerIsLeft ? left : right;
    final target = event.attackerIsLeft ? right : left;

    _activeSequence?.removeFromParent();
    final sequence = AttackSequencePlayer(
      event: event,
      attacker: attacker,
      target: target,
      attackerPosition: attacker.position - Vector2(0, 40),
      targetPosition: target.position - Vector2(0, 40),
    );
    _activeSequence = sequence;
    add(sequence);
  }
}
