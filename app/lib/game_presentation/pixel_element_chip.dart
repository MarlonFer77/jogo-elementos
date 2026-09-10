import 'package:flutter/material.dart';

/// Substitui o `FilterChip` cru na seleção de elementos (Treino e
/// Multiplayer): mesma família visual do `PixelMenuButton` (borda 3px,
/// sombra deslocada). `onTap` nulo desabilita (opacidade reduzida, sem
/// resposta a toque) — mesmo espírito de `PixelMenuButton.onPressed`.
class PixelElementChip extends StatelessWidget {
  const PixelElementChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onTap != null;
    return Opacity(
      opacity: isEnabled ? 1.0 : 0.4,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFF4C94A) : const Color(0xFFF4F4E4),
            border: Border.all(color: const Color(0xFF2B2B2B), width: 3),
            borderRadius: BorderRadius.circular(4),
            boxShadow: const [
              BoxShadow(color: Color(0xFF2B2B2B), offset: Offset(3, 3)),
            ],
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Color(0xFF2B2B2B),
            ),
          ),
        ),
      ),
    );
  }
}
