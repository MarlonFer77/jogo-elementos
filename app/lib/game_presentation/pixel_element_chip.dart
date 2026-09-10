import 'package:flutter/material.dart';

class PixelElementChip extends StatefulWidget {
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
  State<PixelElementChip> createState() => _PixelElementChipState();
}

class _PixelElementChipState extends State<PixelElementChip> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (widget.onTap == null) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onTap != null;
    return Opacity(
      opacity: isEnabled ? 1.0 : 0.4,
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          transform: Matrix4.translationValues(
            _pressed ? 3 : 0,
            _pressed ? 3 : 0,
            0,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: widget.selected
                ? const Color(0xFFF4C94A)
                : const Color(0xFFF4F4E4),
            border: Border.all(color: const Color(0xFF2B2B2B), width: 3),
            borderRadius: BorderRadius.circular(4),
            boxShadow: _pressed
                ? const []
                : const [
                    BoxShadow(color: Color(0xFF2B2B2B), offset: Offset(3, 3)),
                  ],
          ),
          child: Text(
            widget.label,
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
