import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/rendering.dart' show CustomPainter;

const _sky = Color(0xFF8FD3E8);
const _ground = Color(0xFF7CC576);
const _horizonLine = Color(0xFF5FA857);

/// Desenha o "backdrop" da arena (céu, linha de horizonte, chão) em
/// [canvas], ocupando [size]. Compartilhado entre [PixelArenaBackground]
/// (Flame, cena de batalha) e a decoração de fundo da tela inicial — ver
/// docs/superpowers/specs/2026-09-09-home-title-screen-design.md.
void drawArenaBackdrop(Canvas canvas, Size size) {
  final horizon = size.height * 0.62;

  canvas.drawRect(
    Rect.fromLTWH(0, 0, size.width, horizon),
    Paint()..color = _sky,
  );
  canvas.drawRect(
    Rect.fromLTWH(0, horizon, size.width, size.height - horizon),
    Paint()..color = _ground,
  );
  canvas.drawRect(
    Rect.fromLTWH(0, horizon, size.width, 4),
    Paint()..color = _horizonLine,
  );
}

/// `CustomPainter` que desenha [drawArenaBackdrop] — reaproveitado como
/// fundo de qualquer tela Flutter fora do Flame (Home, Treino,
/// Multiplayer). Ver
/// docs/superpowers/specs/2026-09-09-screens-visual-consistency-design.md.
class ArenaBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) => drawArenaBackdrop(canvas, size);

  @override
  bool shouldRepaint(covariant ArenaBackdropPainter oldDelegate) => false;
}

/// Fundo da arena de batalha (Flame) — ver
/// docs/superpowers/specs/2026-09-08-pixel-battle-arena-design.md.
class PixelArenaBackground extends PositionComponent {
  @override
  void render(Canvas canvas) {
    super.render(canvas);
    drawBattleArena(canvas, Size(size.x, size.y));
  }
}

/// Dedicated duel scenery. Menu backgrounds intentionally keep their old art.
/// Fractional anchors match the fighters' floor at 85% in both orientations.
void drawBattleArena(Canvas canvas, Size size) {
  if (size.isEmpty || !size.width.isFinite || !size.height.isFinite) return;
  final w = size.width;
  final h = size.height;
  canvas.save();
  canvas.clipRect(Offset.zero & size);
  void block(double x, double y, double width, double height, int color) {
    canvas.drawRect(
      Rect.fromLTWH(
        x.roundToDouble(),
        y.roundToDouble(),
        width.ceilToDouble(),
        height.ceilToDouble(),
      ),
      Paint()..color = Color(color),
    );
  }

  block(0, 0, w, h, 0xFFA5CED0);
  // Quiet sky behind the HUD; stepped silhouettes rather than gradients.
  for (var i = 0; i < 5; i++) {
    final x = w * (i * .24 - .08);
    final y = h * (.37 + (i.isEven ? 0 : .05));
    block(x, y, w * .3, h * .3, 0xFF779E94);
    block(x + w * .04, y - 12, w * .2, 16, 0xFF779E94);
    block(x + w * .08, y - 20, w * .1, 10, 0xFF779E94);
  }
  block(0, h * .58, w, h * .42, 0xFF608C60);
  for (var i = 0; i < 11; i++) {
    final x = w * i / 10 - 12;
    final y = h * .51 + (i % 3) * 6;
    block(x + 9, y, 6, h * .2, 0xFF695C45);
    block(x - 8, y - 8, 38, 27, 0xFF416C50);
    block(x - 2, y - 20, 26, 20, 0xFF527C57);
    block(x + 4, y - 27, 14, 9, 0xFF668D62);
  }
  // Low stone boundary, with moss, separates the distant woods from the duel.
  block(0, h * .68, w, 12, 0xFF505F52);
  block(0, h * .68, w, 3, 0xFFB6BA90);
  for (var x = 0.0; x < w; x += 30) {
    block(x, h * .68 + 3, 2, 9, 0xFF394F46);
    block(x + 9, h * .68 - 2, 12, 4, 0xFF77965C);
  }
  // Broad continuous floor: no separate platforms obstruct the approach.
  block(w * .04, h * .74, w * .92, h * .18, 0xFF716C53);
  block(w * .025, h * .77, w * .95, h * .12, 0xFF716C53);
  block(w * .04 + 3, h * .74 + 3, w * .92 - 6, h * .17 - 3, 0xFFC2B487);
  block(w * .025 + 3, h * .77 + 3, w * .95 - 6, h * .11 - 3, 0xFFC2B487);
  for (var i = 0; i < 14; i++) {
    final x = w * (.08 + ((i * 7) % 14) / 16);
    final y = h * (.77 + (i % 3) * .045);
    block(x, y, 9, 2, 0xFFA99A72);
    block(x + 9, y - 3, 2, 5, 0xFFA99A72);
  }
  // Restrained foreground tufts, outside the fighters' silhouettes.
  for (var i = 0; i < 18; i++) {
    final x = i * w / 17;
    final y = h * .96 + (i % 2) * 3;
    block(x, y - 5, 3, 8, 0xFF365D45);
    block(x - 3, y - 2, 9, 3, 0xFF365D45);
    block(x + 3, y - 7, 3, 5, 0xFF91AC68);
  }
  canvas.restore();
}
