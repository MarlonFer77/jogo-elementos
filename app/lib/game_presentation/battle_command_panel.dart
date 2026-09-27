import 'package:flutter/material.dart';

import 'sfx_player.dart';

/// Compact handheld-RPG cell; full labels remain available in the tooltip.
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
    child: Tooltip(
      message: [title, ?detail].join(' · '),
      child: AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5),
          boxShadow: selected
              ? const [
                  BoxShadow(color: Color(0xFFB49A55), offset: Offset(0, 2)),
                ]
              : const [],
        ),
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
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                child: Row(
                  children: [
                    if (selected)
                      const Icon(
                        Icons.arrow_right,
                        size: 12,
                        color: Color(0xFF364853),
                      ),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: unavailable
                                  ? const Color(0xFF77766C)
                                  : const Color(0xFF253843),
                            ),
                          ),
                          if (detail != null)
                            Text(
                              detail!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
        ),
      ),
    ),
  );
}

class BattleCommandGrid extends StatelessWidget {
  const BattleCommandGrid({super.key, required this.children, this.columns});
  final List<Widget> children;
  final int? columns;

  @override
  Widget build(BuildContext context) {
    final count =
        columns ??
        (MediaQuery.orientationOf(context) == Orientation.landscape ? 4 : 2);
    return Column(
      children: [
        for (var row = 0; row < children.length; row += count)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var col = 0; col < count; col++) ...[
                    if (col > 0) const SizedBox(width: 4),
                    Expanded(
                      child: row + col < children.length
                          ? children[row + col]
                          : const SizedBox(),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}
