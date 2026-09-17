import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/material.dart' show Colors;

import 'pixel_sprite.dart';

/// Qual lado do campo de batalha um [BattleCharacterComponent] representa.
/// Puramente cosmético (paleta, direção do espelhamento/shake) — sem
/// significado de jogo.
enum BattleSide { left, right }

/// Um combatente genérico, diferenciado só por lado: um sprite em pixel
/// art desenhado em código (ver `pixel_sprite.dart`), um flash+shake breve
/// quando toma dano, e um pulso de escala na preparação de ataque. Barra
/// de HP e indicador de vez moraram no `BattleHudWidget` — não são
/// responsabilidade deste componente.
class BattleCharacterComponent extends PositionComponent {
  static final _upperBody = trainerSpriteGrid.take(14).toList();
  static final _legs = [
    for (var leg = 0; leg < 2; leg++)
      trainerSpriteGrid
          .skip(14)
          .map((row) => row.skip(leg * 8).take(8).toList())
          .toList(),
  ];
  BattleCharacterComponent({required this.side, required Vector2 position})
    : _basePosition = position.clone(),
      super(
        size: Vector2(64, 80),
        position: position,
        anchor: Anchor.bottomCenter,
      );

  final BattleSide side;
  final Vector2 _basePosition;

  static const double _hitEffectDuration = 0.3;
  static const double _prepPulseDuration = 0.15;
  static const double _idleBobAmplitude = 2.0;
  static const double _idleBobPeriodSeconds = 1.6;

  double _hitEffectRemaining = 0;
  double _prepPulseRemaining = 0;
  double _idleTime = 0;
  double _actionOffsetX = 0;
  double _actionLean = 0;
  double _charge = 0;
  double _strike = 0;
  bool _striding = false;

  Vector2 get restPosition => _basePosition.clone();

  /// Cosmetic pose only; the battle has no movement/position rules.
  void setActionPose({
    double offsetX = 0,
    double lean = 0,
    double charge = 0,
    double strike = 0,
    bool striding = false,
  }) {
    _actionOffsetX = offsetX;
    _actionLean = lean;
    _charge = charge;
    _strike = strike;
    _striding = striding;
    position.x = _basePosition.x + offsetX;
  }

  /// Se o flash/shake de dano está tocando agora.
  bool get isPlayingHitEffect => _hitEffectRemaining > 0;

  /// Se o pulso de preparação está tocando agora.
  bool get isPlayingPreparationPulse => _prepPulseRemaining > 0;

  /// Move both the resting anchor and the live sprite when the arena resizes.
  void reposition(Vector2 value) {
    _basePosition.setFrom(value);
    position.setValues(value.x + _actionOffsetX, value.y);
  }

  /// Inicia um flash+shake breve — chamado quando o HP deste lado acabou
  /// de cair (ver `AttackSequencePlayer`).
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
    _idleTime += dt;
    final idleBobY =
        math.sin(_idleTime / _idleBobPeriodSeconds * 2 * math.pi) *
        _idleBobAmplitude;

    if (_hitEffectRemaining <= 0) {
      position.setValues(
        _basePosition.x + _actionOffsetX,
        _basePosition.y + idleBobY,
      );
    } else {
      _hitEffectRemaining = (_hitEffectRemaining - dt).clamp(
        0,
        _hitEffectDuration,
      );
      final progress = _hitEffectRemaining / _hitEffectDuration;
      final shakeX = math.sin(progress * math.pi * 6) * 4 * progress;
      final recoil =
          (side == BattleSide.left ? -1 : 1) *
          8 *
          math.sin((1 - progress) * math.pi);
      position.setValues(
        _basePosition.x + _actionOffsetX + shakeX + recoil,
        _basePosition.y + idleBobY,
      );
    }

    if (_prepPulseRemaining > 0) {
      _prepPulseRemaining = (_prepPulseRemaining - dt).clamp(
        0,
        _prepPulseDuration,
      );
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final pulseScale = isPlayingPreparationPulse
        ? 1.0 + 0.12 * (_prepPulseRemaining / _prepPulseDuration)
        : 1.0;
    final mirror = side == BattleSide.right;

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.x / 2, size.y - 1),
        width: 38,
        height: 8,
      ),
      Paint()..color = const Color(0x3320242B),
    );

    canvas.save();
    canvas.translate(size.x / 2, size.y);
    canvas.scale(mirror ? -pulseScale : pulseScale, pulseScale);
    canvas.rotate(_actionLean + math.sin(_idleTime * 3) * .012);
    canvas.scale(1, 1 + math.sin(_idleTime * 4) * .012);
    canvas.translate(-size.x / 2, -size.y);

    final palette = side == BattleSide.left
        ? pixelPaletteLeft
        : pixelPaletteRight;
    final pixelSize = size.x / trainerSpriteGrid.first.length;
    drawPixelGrid(canvas, _upperBody, palette, pixelSize: pixelSize);
    // Two independently animated legs, using the original pixel art.
    final stride = _striding ? math.sin(_idleTime * 30) * 4 : 0.0;
    for (var leg = 0; leg < 2; leg++) {
      canvas.save();
      canvas.translate(
        leg * 8 * pixelSize,
        14 * pixelSize + (leg == 0 ? stride : -stride),
      );
      drawPixelGrid(canvas, _legs[leg], palette, pixelSize: pixelSize);
      canvas.restore();
    }
    if (_charge > 0 || _strike > 0) {
      final handX = 42 + _strike * 20;
      final handY = 36 - _charge * 20;
      canvas.drawRect(
        Rect.fromLTWH(34, handY + 1, handX - 26, 9),
        Paint()..color = palette[4],
      );
      canvas.drawRect(
        Rect.fromLTWH(handX, handY, 10, 10),
        Paint()..color = palette[1],
      );
      canvas.drawRect(
        Rect.fromLTWH(handX + 2, handY + 2, 6, 6),
        Paint()..color = palette[2],
      );
    }

    if (isPlayingHitEffect) {
      final flashOpacity = (_hitEffectRemaining / _hitEffectDuration).clamp(
        0.0,
        1.0,
      );
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.x, size.y),
        Paint()..color = Colors.white.withValues(alpha: flashOpacity * 0.6),
      );
    }

    canvas.restore();
  }
}
