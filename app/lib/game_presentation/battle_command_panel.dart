import 'package:flutter/material.dart';

import 'sfx_player.dart';

/// A small handheld-RPG command cell. Text wraps; the arena never scrolls.
class BattleCommandButton extends StatelessWidget {
  const BattleCommandButton({
    super.key,
    required this.title,
    this.detail,
    this.selected = false,
    this.unavailable = false,
    this.onPressed,
  });

  final String title;
  final String? detail;
  final bool selected;
  final bool unavailable;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    enabled: onPressed != null,
    child: Material(
      color: selected ? const Color(0xFFF2DB88) : const Color(0xFFF8F2DA),
      shape: const BeveledRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(5)),
        side: BorderSide(color: Color(0xFF364853), width: 2),
      ),
      child: InkWell(
        onTap: onPressed == null
            ? null
            : () {
                sfxPlayer.play(SfxId.tap);
                onPressed!();
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            children: [
              Text(
                selected ? '▶' : '·',
                style: const TextStyle(color: Color(0xFF364853)),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: unavailable
                            ? const Color(0xFF77766C)
                            : const Color(0xFF253843),
                      ),
                    ),
                    if (detail != null)
                      Text(
                        detail!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF646653),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class BattleCommandGrid extends StatelessWidget {
  const BattleCommandGrid({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var row = 0; row < children.length; row += 2)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: children[row]),
                const SizedBox(width: 6),
                Expanded(
                  child: row + 1 < children.length
                      ? children[row + 1]
                      : const SizedBox(),
                ),
              ],
            ),
          ),
        ),
    ],
  );
}
