import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/material.dart' show Colors;

/// Qual lado do campo de batalha um [BattleCharacterComponent] representa.
/// Puramente cosmético (cor, direção do shake) — sem significado de jogo
/// (ver docs/superpowers/specs/2026-09-08-battle-scene-visuals-design.md).
enum BattleSide { left, right }

/// Um combatente genérico, diferenciado só por lado: um "corpo" desenhado
/// em código (sem sprite), uma barra de HP acima, um contorno indicando
/// vez ativa, e um flash+shake breve quando toma dano.
class BattleCharacterComponent extends PositionComponent {
  BattleCharacterComponent({required this.side, required Vector2 position})
      : _basePosition = position.clone(),
        super(size: Vector2(64, 96), position: position, anchor: Anchor.bottomCenter);

  final BattleSide side;
  final Vector2 _basePosition;

  static const double _hitEffectDuration = 0.3;
  static const double _prepPulseDuration = 0.15;
  static const double _hpChaseSpeed = 2.5; // fração por segundo

  double _targetHpFraction = 1.0;
  double _displayedHpFraction = 1.0;
  bool _isActiveTurn = false;
  double _hitEffectRemaining = 0;
  double _prepPulseRemaining = 0;

  Color get _bodyColor =>
      side == BattleSide.left ? const Color(0xFF3B6EA5) : const Color(0xFFA53B3B);

  /// Se o flash/shake de dano está tocando agora.
  bool get isPlayingHitEffect => _hitEffectRemaining > 0;

  /// Se o pulso de preparação está tocando agora.
  bool get isPlayingPreparationPulse => _prepPulseRemaining > 0;

  /// Exposto só para teste — a fração de HP realmente desenhada (persegue
  /// [_targetHpFraction] em vez de saltar direto pro valor novo).
  @visibleForTesting
  double get debugDisplayedHpFraction => _displayedHpFraction;

  void setHpFraction(double fraction) {
    _targetHpFraction = fraction.clamp(0.0, 1.0);
  }

  void setActiveTurn(bool isActive) {
    _isActiveTurn = isActive;
  }

  /// Inicia um flash+shake breve — chamado quando o HP deste lado acabou
  /// de cair (ver `BattleSceneGame.updateView`).
  void playHitEffect() {
    _hitEffectRemaining = _hitEffectDuration;
  }

  /// Inicia um pulso de escala breve — chamado no passo de preparação da
  /// sequência de ataque (`AttackSequencePlayer`).
  void playPreparationPulse() {
    _prepPulseRemaining = _prepPulseDuration;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_hitEffectRemaining <= 0) {
      position.setFrom(_basePosition);
    } else {
      _hitEffectRemaining = (_hitEffectRemaining - dt).clamp(0, _hitEffectDuration);
      final progress = _hitEffectRemaining / _hitEffectDuration;
      final shakeX = math.sin(progress * math.pi * 6) * 4 * progress;
      position.setValues(_basePosition.x + shakeX, _basePosition.y);
    }

    if (_prepPulseRemaining > 0) {
      _prepPulseRemaining = (_prepPulseRemaining - dt).clamp(0, _prepPulseDuration);
    }

    if (_displayedHpFraction != _targetHpFraction) {
      final delta = _targetHpFraction - _displayedHpFraction;
      final step = _hpChaseSpeed * dt;
      _displayedHpFraction = delta.abs() <= step
          ? _targetHpFraction
          : _displayedHpFraction + step * delta.sign;
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final pulseScale = isPlayingPreparationPulse
        ? 1.0 + 0.12 * (_prepPulseRemaining / _prepPulseDuration)
        : 1.0;

    canvas.save();
    if (pulseScale != 1.0) {
      canvas.translate(size.x / 2, size.y);
      canvas.scale(pulseScale);
      canvas.translate(-size.x / 2, -size.y);
    }

    final bodyRect = Rect.fromLTWH(0, size.y * 0.25, size.x, size.y * 0.75);
    final bodyRRect = RRect.fromRectAndRadius(bodyRect, const Radius.circular(12));
    canvas.drawRRect(bodyRRect, Paint()..color = _bodyColor);
    canvas.drawCircle(
      Offset(size.x / 2, size.y * 0.15),
      size.x * 0.22,
      Paint()..color = _bodyColor,
    );

    if (isPlayingHitEffect) {
      final flashOpacity = (_hitEffectRemaining / _hitEffectDuration).clamp(0.0, 1.0);
      canvas.drawRRect(
        bodyRRect,
        Paint()..color = Colors.white.withValues(alpha: flashOpacity * 0.7),
      );
    }

    if (_isActiveTurn) {
      canvas.drawRRect(
        bodyRRect,
        Paint()
          ..color = const Color(0xFFFFD54F)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }

    const barWidth = 56.0;
    const barHeight = 8.0;
    final barLeft = (size.x - barWidth) / 2;
    const barTop = -18.0;
    canvas.drawRect(
      Rect.fromLTWH(barLeft, barTop, barWidth, barHeight),
      Paint()..color = const Color(0xFF2B2B2B),
    );
    canvas.drawRect(
      Rect.fromLTWH(barLeft, barTop, barWidth * _displayedHpFraction, barHeight),
      Paint()
        ..color = _displayedHpFraction > 0.3
            ? const Color(0xFF4CAF50)
            : const Color(0xFFE53935),
    );

    canvas.restore();
  }
}
