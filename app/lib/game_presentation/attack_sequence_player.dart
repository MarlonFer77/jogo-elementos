import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../game_domain/attack_event.dart';
import 'battle_character_component.dart';
import 'element_visuals.dart';
import 'sfx_player.dart';

enum _AttackStep {
  preparation,
  elementalEffect,
  impact,
  damage,
  stateApplied,
  done,
}

const _preparationDuration = 0.15;
const _elementalEffectDuration = 0.2;
const _impactDuration = 0.2;
const _damageDuration = 0.4;
const _stateDuration = 0.3;

/// Toca a sequência visual de um ataque (preparação → efeito elemental →
/// impacto → dano → estado) sobre um par de [BattleCharacterComponent] já
/// existentes na cena. Não decide regra de batalha nenhuma — só reencena
/// visualmente o que [event] diz que já aconteceu. Timer manual (mesmo
/// padrão de [BattleCharacterComponent]), sem o sistema `Effect` do Flame —
/// ver docs/superpowers/specs/2026-09-08-attack-feedback-sequence-design.md.
class AttackSequencePlayer extends Component {
  AttackSequencePlayer({
    required this.event,
    required this.attacker,
    required this.target,
    required Vector2 attackerPosition,
    required Vector2 targetPosition,
    this.onImpact,
    this.onComplete,
  }) : _attackerPosition = attackerPosition,
       _targetPosition = targetPosition;

  final AttackEvent event;
  final VoidCallback? onImpact;
  final VoidCallback? onComplete;
  bool _completionReported = false;
  final BattleCharacterComponent attacker;
  final BattleCharacterComponent target;
  final Vector2 _attackerPosition;
  final Vector2 _targetPosition;

  _AttackStep _step = _AttackStep.preparation;
  double _stepElapsed = 0;
  bool _preparationStarted = false;
  bool _visualsReleased = false;

  bool get isFinished => _step == _AttackStep.done;
  bool get isMelee => event.comboName == null && event.elementIds.length == 1;

  void cancelVisuals() {
    if (_visualsReleased) return;
    _visualsReleased = true;
    attacker.setActionPose();
  }

  @override
  void onRemove() {
    cancelVisuals();
    super.onRemove();
  }

  /// Follow the arena resize without restarting the current attack.
  void updatePositions({
    required Vector2 attackerPosition,
    required Vector2 targetPosition,
  }) {
    _attackerPosition.setFrom(attackerPosition);
    _targetPosition.setFrom(targetPosition);
    _applyMotion();
  }

  void _applyMotion() {
    if (_visualsReleased) return;
    if (event.isDefend) {
      attacker.setActionPose(charge: _step == _AttackStep.done ? 0 : .45);
      return;
    }
    final p = _stepDuration == 0
        ? 1.0
        : (_stepElapsed / _stepDuration).clamp(0.0, 1.0);
    final delta = _targetPosition.x - _attackerPosition.x;
    final direction = delta.sign;
    final travel = math.max(0.0, delta.abs() - 52) * direction;
    if (isMelee) {
      switch (_step) {
        case _AttackStep.preparation:
          attacker.setActionPose(
            offsetX: -direction * 6 * math.sin(p * math.pi),
            lean: -.08,
            swordElement: event.elementIds.first,
          );
        case _AttackStep.elementalEffect:
          attacker.setActionPose(
            offsetX: travel * Curves.easeInOut.transform(p),
            lean: .12,
            swordElement: event.elementIds.first,
            striding: true,
          );
        case _AttackStep.impact:
          attacker.setActionPose(
            offsetX: travel,
            lean: .16,
            strike: p,
            swordElement: event.elementIds.first,
          );
        case _AttackStep.damage:
          attacker.setActionPose(
            offsetX: travel * (1 - Curves.easeOut.transform(p)),
            lean: -.06 * (1 - p),
            swordElement: p < .65 ? event.elementIds.first : null,
            strike: (1 - p * 4).clamp(0.0, 1.0),
            striding: true,
          );
        case _AttackStep.stateApplied:
        case _AttackStep.done:
          attacker.setActionPose();
      }
    } else {
      final charge = switch (_step) {
        _AttackStep.preparation => p * .4,
        _AttackStep.elementalEffect => .4 + p * .6,
        _AttackStep.impact => 1 - p,
        _ => 0.0,
      };
      attacker.setActionPose(
        offsetX: _step == _AttackStep.impact
            ? direction * 8 * math.sin(p * math.pi)
            : -direction * 4 * charge,
        lean: _step == _AttackStep.impact
            ? .12 * math.sin(p * math.pi)
            : -.08 * charge,
        charge: charge,
      );
    }
  }

  double get _stepDuration {
    switch (_step) {
      case _AttackStep.preparation:
        return _preparationDuration;
      case _AttackStep.elementalEffect:
        return _elementalEffectDuration;
      case _AttackStep.impact:
        return _impactDuration;
      case _AttackStep.damage:
        return _damageDuration;
      case _AttackStep.stateApplied:
        return _stateDuration;
      case _AttackStep.done:
        return 0;
    }
  }

  _AttackStep _nextStep(_AttackStep step) {
    switch (step) {
      case _AttackStep.preparation:
        return _AttackStep.elementalEffect;
      case _AttackStep.elementalEffect:
        return _AttackStep.impact;
      case _AttackStep.impact:
        return _AttackStep.damage;
      case _AttackStep.damage:
        return event.appliedStatusNames.isEmpty
            ? _AttackStep.done
            : _AttackStep.stateApplied;
      case _AttackStep.stateApplied:
        return _AttackStep.done;
      case _AttackStep.done:
        return _AttackStep.done;
    }
  }

  @override
  void update(double dt) {
    if (_visualsReleased) return;
    super.update(dt);

    var remaining = dt;
    while (remaining > 0 && _step != _AttackStep.done) {
      if (_step == _AttackStep.preparation && !_preparationStarted) {
        _preparationStarted = true;
        attacker.playPreparationPulse();
        sfxPlayer.play(SfxId.cast);
      }

      final timeLeftInStep = _stepDuration - _stepElapsed;
      if (remaining < timeLeftInStep) {
        _stepElapsed += remaining;
        remaining = 0;
      } else {
        remaining -= timeLeftInStep;
        _stepElapsed = 0;
        final wasStep = _step;
        _step = _nextStep(_step);
        if (wasStep == _AttackStep.impact) {
          if (event.damage > 0 && !event.isDefend) target.playHitEffect();
          if (!event.isDefend) sfxPlayer.play(SfxId.impact);
          onImpact?.call();
        }
      }
    }

    _applyMotion();
    if (_step == _AttackStep.done && !_completionReported) {
      _completionReported = true;
      cancelVisuals();
      onComplete?.call();
      if (parent != null) removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    if (_visualsReleased) return;
    super.render(canvas);
    if (event.isDefend) {
      _drawText(
        canvas,
        'Defesa · 50%',
        Offset(attacker.position.x, attacker.position.y - 90),
        fontSize: 13,
        color: const Color(0xFF253843),
        plateOpacity: 1,
      );
      return;
    }
    switch (_step) {
      case _AttackStep.elementalEffect:
        if (isMelee) {
          _renderMelee(canvas);
        } else {
          _renderChannel(canvas);
        }
        break;
      case _AttackStep.impact:
        if (isMelee) {
          _renderMelee(canvas);
        } else {
          _renderElementalBurst(canvas);
        }
        break;
      case _AttackStep.damage:
        _renderDamageNumber(canvas);
        break;
      case _AttackStep.stateApplied:
        _renderStateText(canvas);
        break;
      case _AttackStep.preparation:
        if (!isMelee) _renderChannel(canvas);
        break;
      case _AttackStep.done:
        break;
    }
  }

  void _renderChannel(Canvas canvas) {
    if (event.elementIds.isEmpty) return;
    final progress = _step == _AttackStep.preparation
        ? _stepElapsed / _preparationDuration * .4
        : .4 + _stepElapsed / _elementalEffectDuration * .6;
    final center = Offset(
      attacker.position.x + (attacker.side == BattleSide.left ? 1 : -1) * 6,
      attacker.position.y - 60,
    );
    for (var i = 0; i < 12; i++) {
      final angle = i * math.pi / 6 + progress * math.pi;
      final radius = 36 - progress * 18;
      final point = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      canvas.drawRect(
        Rect.fromCenter(center: point, width: 4, height: 4),
        Paint()
          ..color = elementColor(event.elementIds[i % event.elementIds.length]),
      );
    }
    for (var i = 0; i < event.elementIds.length; i++) {
      final point =
          center + Offset((i - (event.elementIds.length - 1) / 2) * 14, 0);
      canvas.drawRect(
        Rect.fromCenter(
          center: point,
          width: 6 + progress * 8,
          height: 6 + progress * 8,
        ),
        Paint()..color = elementColor(event.elementIds[i]),
      );
    }
  }

  void _renderMelee(Canvas canvas) {
    final direction = (_targetPosition.x - _attackerPosition.x).sign;
    final color = elementColor(event.elementIds.first);
    if (_step == _AttackStep.impact) {
      final progress = _stepElapsed / _impactDuration;
      for (var i = 0; i < 5; i++) {
        final point = Offset(
          _targetPosition.x - direction * (12 + i * 4),
          _targetPosition.y - 16 + i * 7 + (1 - progress) * 10,
        );
        canvas.drawRect(
          Rect.fromCenter(center: point, width: 5, height: 9),
          Paint()..color = color,
        );
      }
    }
  }

  void _renderElementalBurst(Canvas canvas) {
    final progress = (_stepElapsed / _stepDuration).clamp(0.0, 1.0);
    final travel = _step == _AttackStep.impact ? progress : 0.0;
    final centerX =
        _attackerPosition.x +
        (_targetPosition.x - _attackerPosition.x) * travel;
    final centerY =
        _attackerPosition.y +
        (_targetPosition.y - _attackerPosition.y) * travel;
    final scale = _step == _AttackStep.elementalEffect
        ? progress.clamp(0.2, 1.0)
        : 1.0;

    final count = event.elementIds.length;
    const spacing = 30.0;
    final startX = centerX - spacing * (count - 1) / 2;

    for (var i = 0; i < count; i++) {
      final x = startX + spacing * i;
      final elementId = event.elementIds[i];
      final radius = 14.0 * scale;

      final direction = (_targetPosition.x - _attackerPosition.x).sign;
      for (var trail = 3; trail >= 1; trail--) {
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(x - direction * trail * 9, centerY),
            width: radius * (1 - trail * .16),
            height: radius * (1 - trail * .16),
          ),
          Paint()
            ..color = elementColor(
              elementId,
            ).withValues(alpha: .6 - trail * .12),
        );
      }
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(x, centerY),
          width: radius * 2,
          height: radius * 2,
        ),
        Paint()..color = const Color(0xFF253843),
      );
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(x, centerY),
          width: radius * 2 - 4,
          height: radius * 2 - 4,
        ),
        Paint()..color = elementColor(elementId),
      );
      _drawText(
        canvas,
        elementSymbol(elementId),
        Offset(x, centerY),
        fontSize: 18 * scale,
      );
    }
  }

  void _renderDamageNumber(Canvas canvas) {
    final progress = (_stepElapsed / _stepDuration).clamp(0.0, 1.0);
    final riseY = _targetPosition.y - 20 - (progress * 20);
    final opacity = (1.0 - progress).clamp(0.0, 1.0);

    _drawText(
      canvas,
      event.damage > 0 ? '-${event.damage}' : 'Sem dano',
      Offset(_targetPosition.x, riseY),
      fontSize: 20,
      color: Color.fromRGBO(119, 37, 33, opacity),
      bold: true,
      plateOpacity: opacity,
    );
  }

  void _renderStateText(Canvas canvas) {
    final progress = (_stepElapsed / _stepDuration).clamp(0.0, 1.0);
    final opacity = (1.0 - progress).clamp(0.0, 1.0);

    _drawText(
      canvas,
      event.appliedStatusNames.join(', '),
      Offset(_targetPosition.x, _targetPosition.y - 20),
      fontSize: 14,
      color: Color.fromRGBO(255, 255, 255, opacity),
    );
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset center, {
    double fontSize = 16,
    Color color = Colors.white,
    bool bold = false,
    double? plateOpacity,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          color: color,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    if (plateOpacity != null) {
      final plate = Rect.fromCenter(
        center: center,
        width: painter.width + 12,
        height: painter.height + 6,
      );
      canvas.drawRect(
        plate.inflate(2),
        Paint()
          ..color = const Color(0xFF253843).withValues(alpha: plateOpacity),
      );
      canvas.drawRect(
        plate,
        Paint()
          ..color = const Color(0xFFF8F2DA).withValues(alpha: plateOpacity),
      );
    }
    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
    );
  }
}
