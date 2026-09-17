import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/material.dart' show Colors;

import 'pixel_sprite.dart';
import 'element_visuals.dart';

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
  String? _swordElement;

  /// The weapon belongs only to the current visual action, never to a build.
  String? get swordElement => _swordElement;

  Vector2 get restPosition => _basePosition.clone();

  /// Cosmetic pose only; the battle has no movement/position rules.
  void setActionPose({
    double offsetX = 0,
    double lean = 0,
    double charge = 0,
    double strike = 0,
    bool striding = false,
    String? swordElement,
  }) {
    _actionOffsetX = offsetX;
    _actionLean = lean;
    _charge = charge;
    _strike = strike;
    _striding = striding;
    _swordElement = swordElement;
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
    final sway =
        math.sin(_idleTime * (_striding ? 30 : 4)) * (_striding ? 5 : 1.5);
    final armed = _swordElement != null;
    final backHand = Offset(10 + _charge * 12, 51 - _charge * 31 - sway);
    final frontHand = Offset(
      52 + (armed ? _strike * 7 : _charge * 3),
      51 - _charge * 31 - (armed ? 15 - _strike * 9 : 0) + sway,
    );
    _drawArm(canvas, palette, const Offset(16, 30), backHand);
    _drawArm(canvas, palette, const Offset(46, 30), frontHand);
    if (armed) _drawSword(canvas, frontHand, _swordElement!);

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

  void _drawArm(
    Canvas canvas,
    List<Color> palette,
    Offset shoulder,
    Offset hand,
  ) {
    final elbow = Offset(shoulder.dx, (shoulder.dy + hand.dy) / 2 + 4);
    final path = Path()
      ..moveTo(shoulder.dx, shoulder.dy)
      ..lineTo(elbow.dx, elbow.dy)
      ..lineTo(hand.dx, hand.dy);
    canvas.drawPath(
      path,
      Paint()
        ..color = palette[1]
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = palette[4]
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6,
    );
    canvas.drawRect(
      Rect.fromCenter(center: hand, width: 10, height: 10),
      Paint()..color = palette[1],
    );
    canvas.drawRect(
      Rect.fromCenter(center: hand, width: 6, height: 6),
      Paint()..color = palette[2],
    );
  }

  void _drawSword(Canvas canvas, Offset hand, String element) {
    canvas.save();
    canvas.translate(hand.dx, hand.dy);
    // Raised guard -> forward cut. Parent transform mirrors the entire grip.
    canvas.rotate(-.35 + _strike * 2.05);
    void rect(double x, double y, double w, double h, Color color) =>
        canvas.drawRect(Rect.fromLTWH(x, y, w, h), Paint()..color = color);
    const outline = Color(0xFF253843);
    final color = elementColor(element);
    rect(-3, -7, 6, 14, outline);
    rect(-1, -5, 2, 10, const Color(0xFFAD8156));
    rect(-6, -36, 12, 25, outline);
    rect(-4, -41, 8, 7, outline);
    rect(-2, -44, 4, 5, outline);
    rect(-4, -35, 8, 24, color);
    rect(-2, -40, 4, 29, color);
    rect(-2, -35, 2, 21, Color.lerp(color, Colors.white, .7)!);
    rect(-10, -13, 20, 6, outline);
    rect(-8, -11, 16, 2, const Color(0xFFE4C681));
    rect(-2, -12, 4, 4, color);
    canvas.restore();
  }
}
