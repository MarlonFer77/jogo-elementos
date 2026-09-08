import 'dart:ui';

import 'package:flame/components.dart';

/// Fundo da arena: poucos blocos de cor sólida (céu, linha de horizonte,
/// chão) desenhados em código — sem imagem nenhuma, pra combinar com os
/// personagens em pixel art. Ver
/// docs/superpowers/specs/2026-09-08-pixel-battle-arena-design.md.
class PixelArenaBackground extends PositionComponent {
  static const _sky = Color(0xFF8FD3E8);
  static const _ground = Color(0xFF7CC576);
  static const _horizonLine = Color(0xFF5FA857);

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final horizon = size.y * 0.62;

    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, horizon), Paint()..color = _sky);
    canvas.drawRect(
      Rect.fromLTWH(0, horizon, size.x, size.y - horizon),
      Paint()..color = _ground,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, horizon, size.x, 4),
      Paint()..color = _horizonLine,
    );
  }
}
