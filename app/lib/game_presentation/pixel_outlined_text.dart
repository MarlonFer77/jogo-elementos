import 'package:flutter/material.dart';

/// Texto com contorno grosso simulado via `TextStyle.shadows` (vários
/// `Shadow`s deslocados, sem blur) — sem fonte pixel de verdade, sem asset
/// novo. Usado no título da Home (`fontSize` grande) e nos títulos das
/// outras telas (menor). Ver
/// docs/superpowers/specs/2026-09-09-screens-visual-consistency-design.md.
class PixelOutlinedText extends StatelessWidget {
  const PixelOutlinedText(
    this.text, {
    super.key,
    this.fontSize = 40,
    this.color = const Color(0xFFF4F4E4),
  });

  final String text;
  final double fontSize;
  final Color color;

  @override
  Widget build(BuildContext context) {
    const shadowColor = Color(0xFF2B2B2B);
    final outlineOffset = fontSize > 24 ? 2.0 : 1.5;
    final dropOffset = fontSize > 24 ? 3.0 : 2.0;
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'monospace',
        fontWeight: FontWeight.bold,
        fontSize: fontSize,
        letterSpacing: fontSize > 24 ? 4 : 1,
        color: color,
        shadows: [
          for (final dx in [-outlineOffset, outlineOffset])
            for (final dy in [-outlineOffset, outlineOffset])
              Shadow(offset: Offset(dx, dy), color: shadowColor),
          Shadow(offset: Offset(dropOffset, dropOffset), color: shadowColor),
        ],
      ),
    );
  }
}
