import 'package:flutter/material.dart';

import 'pixel_sprite.dart';

/// Um dos dois personagens da batalha, desenhado fora do Flame — usado
/// como decoração estática (ex: tela inicial). Reaproveita [drawPixelGrid]
/// direto: `CustomPainter.paint` já entrega o mesmo `Canvas` que
/// [drawPixelGrid] espera, sem adaptação nenhuma. Ver
/// docs/superpowers/specs/2026-09-09-home-title-screen-design.md.
class TrainerSpriteImage extends StatelessWidget {
  const TrainerSpriteImage({
    super.key,
    this.mirror = false,
    this.size = const Size(96, 120),
  });

  final bool mirror;
  final Size size;

  @override
  Widget build(BuildContext context) {
    return Transform.flip(
      flipX: mirror,
      child: CustomPaint(
        size: size,
        painter: _TrainerSpritePainter(mirror ? pixelPaletteRight : pixelPaletteLeft),
      ),
    );
  }
}

class _TrainerSpritePainter extends CustomPainter {
  _TrainerSpritePainter(this.palette);

  final List<Color> palette;

  @override
  void paint(Canvas canvas, Size size) {
    final pixelSize = size.width / trainerSpriteGrid.first.length;
    drawPixelGrid(canvas, trainerSpriteGrid, palette, pixelSize: pixelSize);
  }

  @override
  bool shouldRepaint(covariant _TrainerSpritePainter oldDelegate) =>
      oldDelegate.palette != palette;
}
