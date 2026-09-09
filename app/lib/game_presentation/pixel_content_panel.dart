import 'package:flutter/material.dart';

/// Painel "cartão" — fundo quase opaco, borda escura — pra manter o
/// conteúdo (texto, chips, campos) legível por cima do fundo pixelado da
/// arena. Mesmo espírito visual do `BattleHudWidget`/`PixelMenuButton`.
/// Ver docs/superpowers/specs/2026-09-09-screens-visual-consistency-design.md.
class PixelContentPanel extends StatelessWidget {
  const PixelContentPanel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xF2F4F4E4),
        border: Border.all(color: const Color(0xFF2B2B2B), width: 3),
        borderRadius: BorderRadius.circular(6),
      ),
      child: child,
    );
  }
}
