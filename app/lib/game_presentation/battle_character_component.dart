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
  BattleCharacterComponent({required this.side, required Vector2 position})
      : _basePosition = position.clone(),
        super(size: Vector2(64, 80), position: position, anchor: Anchor.bottomCenter);

  final BattleSide side;
  final Vector2 _basePosition;

  static const double _hitEffectDuration = 0.3;
  static const double _prepPulseDuration = 0.15;

  double _hitEffectRemaining = 0;
  double _prepPulseRemaining = 0;

  /// Se o flash/shake de dano está tocando agora.
  bool get isPlayingHitEffect => _hitEffectRemaining > 0;

  /// Se o pulso de preparação está tocando agora.
  bool get isPlayingPreparationPulse => _prepPulseRemaining > 0;

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
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final pulseScale = isPlayingPreparationPulse
        ? 1.0 + 0.12 * (_prepPulseRemaining / _prepPulseDuration)
        : 1.0;
    final mirror = side == BattleSide.right;

    canvas.save();
    canvas.translate(size.x / 2, size.y);
    canvas.scale(mirror ? -pulseScale : pulseScale, pulseScale);
    canvas.translate(-size.x / 2, -size.y);

    final palette = side == BattleSide.left ? pixelPaletteLeft : pixelPaletteRight;
    final pixelSize = size.x / trainerSpriteGrid.first.length;
    drawPixelGrid(canvas, trainerSpriteGrid, palette, pixelSize: pixelSize);

    if (isPlayingHitEffect) {
      final flashOpacity = (_hitEffectRemaining / _hitEffectDuration).clamp(0.0, 1.0);
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.x, size.y),
        Paint()..color = Colors.white.withValues(alpha: flashOpacity * 0.6),
      );
    }

    canvas.restore();
  }
}
