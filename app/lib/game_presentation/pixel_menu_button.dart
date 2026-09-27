import 'package:flutter/material.dart';

import 'sfx_player.dart';

class PixelMenuButton extends StatefulWidget {
  const PixelMenuButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.primary = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  State<PixelMenuButton> createState() => _PixelMenuButtonState();
}

class _PixelMenuButtonState extends State<PixelMenuButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (widget.onPressed == null) return;
    setState(() => _pressed = value);
  }

  void _handleTap() {
    sfxPlayer.play(SfxId.tap);
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null;
    final compact =
        MediaQuery.sizeOf(context).height < 740 ||
        MediaQuery.orientationOf(context) == Orientation.landscape;
    return Semantics(
      button: true,
      enabled: isEnabled,
      child: AnimatedOpacity(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 120),
        opacity: isEnabled ? 1.0 : 0.4,
        child: GestureDetector(
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          onTap: isEnabled ? _handleTap : null,
          child: AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 80),
            transform: Matrix4.translationValues(
              _pressed ? 3 : 0,
              _pressed ? 3 : 0,
              0,
            ),
            constraints: const BoxConstraints(minHeight: 48),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 10 : 16,
              vertical: compact ? 6 : 10,
            ),
            decoration: BoxDecoration(
              color: widget.primary
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
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      fontSize: compact ? 13 : 15,
                      letterSpacing: .4,
                      color: Color(0xFF2B2B2B),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.arrow_right,
                  size: 18,
                  color: Color(0xFF2B2B2B),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
