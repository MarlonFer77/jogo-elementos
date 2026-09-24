import 'package:flutter/material.dart';

import 'pixel_arena_background.dart';
import 'pixel_outlined_text.dart';
import 'trainer_sprite_image.dart';

/// Ilustração nativa: reaproveita a arena e os sprites sem iniciar o engine.
class HomeTitleScene extends StatelessWidget {
  const HomeTitleScene({super.key});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.22,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFB6A16D), width: 3),
          boxShadow: const [
            BoxShadow(color: Color(0xFF0E2022), offset: Offset(5, 5)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: ClipRect(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final h = constraints.maxHeight;
                final spriteWidth = w * .22;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    const CustomPaint(painter: _TitleArenaPainter()),
                    Positioned(
                      top: h * .08,
                      left: 18,
                      right: 18,
                      child: Column(
                        children: [
                          const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: PixelOutlinedText(
                              'ELEMENTOS',
                              fontSize: 44,
                              color: Color(0xFFF4D782),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            color: const Color(0xFF283C36),
                            child: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'DESCUBRA · CONJURE · DOMINE',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFF1E8C9),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    for (final mirror in [false, true])
                      Positioned(
                        left: w * (mirror ? .64 : .14),
                        bottom: h * .16,
                        child: ExcludeSemantics(
                          child: TrainerSpriteImage(
                            mirror: mirror,
                            size: Size(spriteWidth, spriteWidth * 1.25),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _TitleArenaPainter extends CustomPainter {
  const _TitleArenaPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // A fixed art grid keeps the scenery's pixels consistent on large screens.
    canvas.save();
    canvas.scale(size.width / 360, size.height / 295);
    drawBattleArena(canvas, const Size(360, 295));
    final paint = Paint()..isAntiAlias = false;
    void block(double x, double y, double w, double h, Color color) {
      canvas.drawRect(Rect.fromLTWH(x, y, w, h), paint..color = color);
    }

    const cream = Color(0xFFD7E3CD);
    block(18, 87, 48, 6, cream);
    block(27, 81, 24, 6, cream);
    block(284, 99, 55, 6, cream);
    block(298, 93, 24, 6, cream);

    // Conjuration emblem links the title art to the actual gesture mechanic.
    final seal = Path()
      ..moveTo(180, 139)
      ..lineTo(203, 170)
      ..lineTo(180, 201)
      ..lineTo(157, 170)
      ..close();
    canvas.drawPath(
      seal,
      Paint()
        ..color = const Color(0xFF283C36)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..isAntiAlias = false,
    );
    canvas.drawPath(
      seal,
      Paint()
        ..color = const Color(0xFFE1C778)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..isAntiAlias = false,
    );
    for (final node in [
      (180.0, 139.0, const Color(0xFFD88650)),
      (203.0, 170.0, const Color(0xFF75AEC1)),
      (180.0, 201.0, const Color(0xFFA4B569)),
      (157.0, 170.0, const Color(0xFFE1C778)),
    ]) {
      block(node.$1 - 5, node.$2 - 5, 10, 10, const Color(0xFF283C36));
      block(node.$1 - 3, node.$2 - 3, 6, 6, node.$3);
    }
    block(177, 165, 6, 10, const Color(0xFFF1E8C9));
    block(175, 168, 10, 4, const Color(0xFFF1E8C9));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TitleArenaPainter oldDelegate) => false;
}
