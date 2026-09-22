import 'package:flame/game.dart';

import '../game_domain/attack_event.dart';
import '../game_domain/battle_scene_view.dart';
import 'attack_sequence_player.dart';
import 'battle_character_component.dart';
import 'pixel_arena_background.dart';

/// Se [currentHp] deve ser tratado como dano em relação a [previousHp].
/// `previousHp == null` (primeira leitura, ainda sem baseline) nunca conta
/// como dano. Pura e sem efeito colateral — fica fora de qualquer
/// componente do Flame para ser testável sem o game loop.
bool didTakeDamage({required int? previousHp, required int currentHp}) {
  return previousHp != null && currentHp < previousHp;
}

/// Jogo Flame que renderiza um [BattleSceneView]: um fundo procedural mais
/// dois personagens genéricos em pixel art (um por lado), com sequência de
/// ataque quando uma combinação é jogada. Barra de HP e indicador de vez
/// moram no `BattleHudWidget` (Flutter, fora deste jogo). Apresentação
/// pura — nenhuma regra de batalha mora aqui; o estado a renderizar vem de
/// fora via [updateView].
class BattleSceneGame extends FlameGame {
  void Function(AttackEvent event)? onAttackImpact;
  void Function(AttackEvent event)? onAttackComplete;
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

    final background = PixelArenaBackground()
      ..size = size
      ..priority = -1;
    add(background);

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
    _left?.reposition(Vector2(size.x * 0.25, size.y * 0.85));
    _right?.reposition(Vector2(size.x * 0.75, size.y * 0.85));
    final sequence = _activeSequence;
    if (sequence != null && _left != null && _right != null) {
      final attacker = sequence.event.attackerIsLeft ? _left! : _right!;
      final target = sequence.event.attackerIsLeft ? _right! : _left!;
      sequence.updatePositions(
        attackerPosition: attacker.restPosition - Vector2(0, 40),
        targetPosition: target.restPosition - Vector2(0, 40),
      );
    }
    for (final child in children.whereType<PixelArenaBackground>()) {
      child.size = size;
    }
  }

  /// Reflete [view] na cena: dispara a sequência de ataque quando
  /// [BattleSceneView.lastAttack] traz um evento novo, ou (defensivamente)
  /// um flash simples se o HP caiu sem nenhum evento. Seguro chamar antes
  /// do `onLoad` terminar (guarda a view pendente e aplica assim que os
  /// personagens existirem).
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

    left.setFrozen(view.leftStatuses.any((status) => status.id == 'freeze'));
    right.setFrozen(view.rightStatuses.any((status) => status.id == 'freeze'));

    final attack = view.lastAttack;
    if (attack == null) {
      _activeSequence?.cancelVisuals();
      _activeSequence?.removeFromParent();
      _activeSequence = null;
      _lastPlayedSequenceId = null;
    }
    if (attack != null && attack.sequenceId != _lastPlayedSequenceId) {
      _lastPlayedSequenceId = attack.sequenceId;
      _playAttackSequence(attack);
    } else if (didTakeDamage(
          previousHp: _lastLeftHp,
          currentHp: view.leftCurrentHp,
        ) ||
        didTakeDamage(
          previousHp: _lastRightHp,
          currentHp: view.rightCurrentHp,
        )) {
      // Fallback defensivo: HP caiu mas nenhum AttackEvent chegou (não
      // deveria acontecer — só combinação causa dano, e toda combinação
      // vira AttackEvent nas telas). Mantém pelo menos o flash simples de
      // antes em vez de dano silencioso.
      if (didTakeDamage(
        previousHp: _lastLeftHp,
        currentHp: view.leftCurrentHp,
      )) {
        left.playHitEffect();
      }
      if (didTakeDamage(
        previousHp: _lastRightHp,
        currentHp: view.rightCurrentHp,
      )) {
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

    _activeSequence?.cancelVisuals();
    _activeSequence?.removeFromParent();
    final sequence = AttackSequencePlayer(
      event: event,
      attacker: attacker,
      target: target,
      attackerPosition: attacker.restPosition - Vector2(0, 40),
      targetPosition: target.restPosition - Vector2(0, 40),
      onImpact: () {
        if (identical(_activeSequence?.event, event)) {
          onAttackImpact?.call(event);
        }
      },
      onComplete: () {
        if (!identical(_activeSequence?.event, event)) return;
        _activeSequence = null;
        onAttackComplete?.call(event);
      },
    );
    _activeSequence = sequence;
    add(sequence);
  }
}
