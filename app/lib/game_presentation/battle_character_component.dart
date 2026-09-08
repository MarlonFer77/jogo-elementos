import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
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

  double _hpFraction = 1.0;
  bool _isActiveTurn = false;
  double _hitEffectRemaining = 0;

  Color get _bodyColor =>
      side == BattleSide.left ? const Color(0xFF3B6EA5) : const Color(0xFFA53B3B);

  /// Se o flash/shake de dano está tocando agora.
  bool get isPlayingHitEffect => _hitEffectRemaining > 0;

  void setHpFraction(double fraction) {
    _hpFraction = fraction.clamp(0.0, 1.0);
  }

  void setActiveTurn(bool isActive) {
    _isActiveTurn = isActive;
  }

  /// Inicia um flash+shake breve — chamado quando o HP deste lado acabou
  /// de cair (ver `BattleSceneGame.updateView`).
  void playHitEffect() {
    _hitEffectRemaining = _hitEffectDuration;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_hitEffectRemaining <= 0) {
      position.setFrom(_basePosition);
      return;
    }

    _hitEffectRemaining = (_hitEffectRemaining - dt).clamp(0, _hitEffectDuration);
    final progress = _hitEffectRemaining / _hitEffectDuration;
    final shakeX = math.sin(progress * math.pi * 6) * 4 * progress;
    position.setValues(_basePosition.x + shakeX, _basePosition.y);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

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
      Rect.fromLTWH(barLeft, barTop, barWidth * _hpFraction, barHeight),
      Paint()
        ..color = _hpFraction > 0.3
            ? const Color(0xFF4CAF50)
            : const Color(0xFFE53935),
    );
  }
}
