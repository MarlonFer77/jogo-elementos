import 'package:flame/game.dart';

import '../game_domain/attack_event.dart';
import '../game_domain/battle_scene_view.dart';
import '../game_domain/combination_catalog.dart';
import 'attack_sequence_player.dart';
import 'battle_character_component.dart';
import 'pixel_arena_background.dart';
import 'sfx_player.dart';

/// Se [currentHp] deve ser tratado como dano em relação a [previousHp].
/// `previousHp == null` (primeira leitura, ainda sem baseline) nunca conta
/// como dano. Pura e sem efeito colateral — fica fora de qualquer
/// componente do Flame para ser testável sem o game loop.
bool didTakeDamage({required int? previousHp, required int currentHp}) {
  return previousHp != null && currentHp < previousHp;
}

/// Jogo Flame que renderiza um [BattleSceneView]: um fundo procedural mais
/// dois combatentes em pixel art (avatar ou criatura), com sequência de
/// ataque quando uma combinação é jogada. Barra de HP e indicador de vez
/// moram no `BattleHudWidget` (Flutter, fora deste jogo). Apresentação
/// pura — nenhuma regra de batalha mora aqui; o estado a renderizar vem de
/// fora via [updateView].
class BattleSceneGame extends FlameGame {
  bool ambientMotionEnabled = true;
  final _background = PixelArenaBackground();
  bool _waitingForImpact = false;
  bool? _channelingLeft;
  void setChanneling(bool? left) {
    if (_channelingLeft == left) return;
    if (_channelingLeft != null) {
      (_channelingLeft! ? _left : _right)?.setActionPose();
    }
    _channelingLeft = left;
    if (left != null) {
      (left ? _left : _right)?.playPreparationPulse();
      sfxPlayer.play(SfxId.cast);
    }
  }

  @override
  void update(double dt) {
    _background.motionEnabled = ambientMotionEnabled;
    super.update(dt);
    if (_channelingLeft != null) {
      (_channelingLeft! ? _left : _right)?.setActionPose(
        charge: .85,
        lean: -.06,
      );
    }
  }

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

    final background = _background
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
    _background.size = size;
  }

  /// Reflete [view] na cena: dispara a sequência de ataque quando
  /// [BattleSceneView.lastAttack] traz um evento novo, ou (defensivamente)
  /// um flash simples se o HP caiu sem nenhum evento. Seguro chamar antes
  /// do `onLoad` terminar (guarda a view pendente e aplica assim que os
  /// personagens existirem).
  void updateView(BattleSceneView view) {
    _pendingView = view;
    if (_left == null || _right == null) {
      return;
    }
    _applyView(view);
  }

  void _applyView(BattleSceneView view) {
    final left = _left!;
    final right = _right!;

    _background.theme = view.arena;

    left.appearance = view.leftAppearance;
    right.appearance = view.rightAppearance;

    final attack = view.lastAttack;
    if (attack == null) {
      _activeSequence?.cancelVisuals();
      _activeSequence?.removeFromParent();
      _activeSequence = null;
      _lastPlayedSequenceId = null;
      _waitingForImpact = false;
    }
    if (attack != null && attack.sequenceId != _lastPlayedSequenceId) {
      _lastPlayedSequenceId = attack.sequenceId;
      _waitingForImpact = true;
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

    if (!_waitingForImpact) _applyStatuses(view);
    _lastLeftHp = view.leftCurrentHp;
    _lastRightHp = view.rightCurrentHp;
  }

  void _applyStatuses(BattleSceneView view) {
    for (final (character, statuses) in [
      (_left!, view.leftStatuses),
      (_right!, view.rightStatuses),
    ]) {
      character.setFrozen(statuses.any((s) => s.id == 'freeze'));
      character.hasShield = statuses.any((s) => s.id == 'shield');
      character.hasGuard = statuses.any((s) => s.id == 'guard');
    }
  }

  void _playAttackSequence(AttackEvent event) {
    final left = _left!;
    final right = _right!;
    final attacker = event.attackerIsLeft ? left : right;
    final target = event.attackerIsLeft ? right : left;
    final offensive =
        !event.isDefend &&
        !event.isFrozenRecovery &&
        !event.isFizzle &&
        (event.elementIds.length == 1 ||
            (const CombinationCatalog()
                        .byElements(event.elementIds)
                        ?.directDamage ??
                    0) >
                0);

    _activeSequence?.cancelVisuals();
    _activeSequence?.removeFromParent();
    final sequence = AttackSequencePlayer(
      event: event,
      attacker: attacker,
      target: target,
      targetShielded: offensive && target.hasShield,
      targetGuarded: offensive && target.hasGuard,
      impactParticles: ambientMotionEnabled,
      attackerPosition: attacker.restPosition - Vector2(0, 40),
      targetPosition: target.restPosition - Vector2(0, 40),
      onImpact: () {
        if (identical(_activeSequence?.event, event)) {
          _waitingForImpact = false;
          if (_pendingView != null) _applyStatuses(_pendingView!);
          onAttackImpact?.call(event);
        }
      },
      onComplete: () {
        if (!identical(_activeSequence?.event, event)) return;
        _activeSequence = null;
        _waitingForImpact = false;
        onAttackComplete?.call(event);
      },
    );
    _activeSequence = sequence;
    add(sequence);
  }
}
