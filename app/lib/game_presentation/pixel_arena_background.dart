import 'dart:ui';

import 'package:flame/components.dart';

const _sky = Color(0xFF8FD3E8);
const _ground = Color(0xFF7CC576);
const _horizonLine = Color(0xFF5FA857);

/// Desenha o "backdrop" da arena (céu, linha de horizonte, chão) em
/// [canvas], ocupando [size]. Compartilhado entre [PixelArenaBackground]
/// (Flame, cena de batalha) e a decoração de fundo da tela inicial — ver
/// docs/superpowers/specs/2026-09-09-home-title-screen-design.md.
void drawArenaBackdrop(Canvas canvas, Size size) {
  final horizon = size.height * 0.62;

  canvas.drawRect(Rect.fromLTWH(0, 0, size.width, horizon), Paint()..color = _sky);
  canvas.drawRect(
    Rect.fromLTWH(0, horizon, size.width, size.height - horizon),
    Paint()..color = _ground,
  );
  canvas.drawRect(
    Rect.fromLTWH(0, horizon, size.width, 4),
    Paint()..color = _horizonLine,
  );
}

/// Fundo da arena de batalha (Flame) — ver
/// docs/superpowers/specs/2026-09-08-pixel-battle-arena-design.md.
class PixelArenaBackground extends PositionComponent {
  @override
  void render(Canvas canvas) {
    super.render(canvas);
    drawArenaBackdrop(canvas, Size(size.x, size.y));
  }
}
