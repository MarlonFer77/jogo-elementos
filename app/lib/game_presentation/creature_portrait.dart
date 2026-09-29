import 'package:flutter/material.dart';
import '../game_domain/combatant_appearance.dart';
import 'creature_art.dart';

/// Uses the exact battle art, so the room preview identifies its enemy.
class CreaturePortrait extends StatelessWidget {
  const CreaturePortrait({
    super.key,
    required this.appearance,
    required this.label,
  });
  final CombatantAppearance appearance;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    image: true,
    child: SizedBox(
      width: 48,
      height: 56,
      child: CustomPaint(painter: _PortraitPainter(appearance)),
    ),
  );
}

class _PortraitPainter extends CustomPainter {
  const _PortraitPainter(this.appearance);
  final CombatantAppearance appearance;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate((size.width - size.height * .8) / 2, 0);
    canvas.scale(size.height / 80);
    CreatureArt.draw(canvas, appearance);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PortraitPainter oldDelegate) =>
      oldDelegate.appearance != appearance;
}
