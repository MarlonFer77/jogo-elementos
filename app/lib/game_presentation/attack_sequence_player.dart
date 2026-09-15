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
    this.onComplete,
  }) : _attackerPosition = attackerPosition,
       _targetPosition = targetPosition;

  final AttackEvent event;
  final VoidCallback? onComplete;
  bool _completionReported = false;
  final BattleCharacterComponent attacker;
  final BattleCharacterComponent target;
  final Vector2 _attackerPosition;
  final Vector2 _targetPosition;

  _AttackStep _step = _AttackStep.preparation;
  double _stepElapsed = 0;
  bool _preparationStarted = false;

  bool get isFinished => _step == _AttackStep.done;

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
          target.playHitEffect();
          sfxPlayer.play(SfxId.impact);
        }
      }
    }

    if (_step == _AttackStep.done && !_completionReported) {
      _completionReported = true;
      onComplete?.call();
      if (parent != null) removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    switch (_step) {
      case _AttackStep.elementalEffect:
      case _AttackStep.impact:
        _renderElementalBurst(canvas);
        break;
      case _AttackStep.damage:
        _renderDamageNumber(canvas);
        break;
      case _AttackStep.stateApplied:
        _renderStateText(canvas);
        break;
      case _AttackStep.preparation:
      case _AttackStep.done:
        break;
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

      canvas.drawCircle(
        Offset(x, centerY),
        radius,
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
      '-${event.damage}',
      Offset(_targetPosition.x, riseY),
      fontSize: 20,
      color: Color.fromRGBO(255, 82, 82, opacity),
      bold: true,
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
    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
    );
  }
}
