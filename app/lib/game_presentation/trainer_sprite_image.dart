import 'package:flutter/material.dart';

import 'pixel_sprite.dart';

/// Um dos dois personagens da batalha, desenhado fora do Flame — usado
/// como decoração estática (ex: tela inicial). Reaproveita [drawPixelGrid]
/// direto: `CustomPainter.paint` já entrega o mesmo `Canvas` que
/// [drawPixelGrid] espera, sem adaptação nenhuma. Balança sutilmente no
/// eixo Y (idle) pra parecer vivo — ver
/// docs/superpowers/specs/2026-09-10-animation-and-element-picker-design.md.
class TrainerSpriteImage extends StatefulWidget {
  const TrainerSpriteImage({
    super.key,
    this.mirror = false,
    this.size = const Size(96, 120),
  });

  final bool mirror;
  final Size size;

  @override
  State<TrainerSpriteImage> createState() => _TrainerSpriteImageState();
}

class _TrainerSpriteImageState extends State<TrainerSpriteImage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);
  late final Animation<double> _idleOffset = Tween<double>(begin: -2, end: 2)
      .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _idleOffset,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _idleOffset.value),
          child: child,
        );
      },
      child: Transform.flip(
        flipX: widget.mirror,
        child: CustomPaint(
          size: widget.size,
          painter: _TrainerSpritePainter(
            widget.mirror ? pixelPaletteRight : pixelPaletteLeft,
          ),
        ),
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
