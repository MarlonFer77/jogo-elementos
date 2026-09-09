import 'package:flutter/material.dart';

/// Botão blocudo estilo jogo de luta — mesmo espírito visual do painel
/// de HP da batalha (`BattleHudWidget`). [primary] dá um fundo mais
/// destacado (ação mais comum). Sem animação customizada: só um
/// `GestureDetector` sobre o retângulo decorado. Ver
/// docs/superpowers/specs/2026-09-09-home-title-screen-design.md.
class PixelMenuButton extends StatelessWidget {
  const PixelMenuButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.primary = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: primary ? const Color(0xFFF4C94A) : const Color(0xFFF4F4E4),
          border: Border.all(color: const Color(0xFF2B2B2B), width: 3),
          borderRadius: BorderRadius.circular(4),
          boxShadow: const [
            BoxShadow(color: Color(0xFF2B2B2B), offset: Offset(3, 3)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                fontSize: 16,
                letterSpacing: 1,
                color: Color(0xFF2B2B2B),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              '▶',
              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2B2B2B)),
            ),
          ],
        ),
      ),
    );
  }
}
