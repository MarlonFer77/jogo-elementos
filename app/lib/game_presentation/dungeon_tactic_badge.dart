import 'package:flutter/material.dart';
import '../game_domain/dungeon_catalog.dart';

class DungeonTacticBadge extends StatelessWidget {
  const DungeonTacticBadge({
    super.key,
    required this.tactic,
    this.compact = false,
  });
  final DungeonTactic tactic;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (tactic) {
      DungeonTactic.assault => (
        Icons.local_fire_department,
        const Color(0xFF893F2B),
      ),
      DungeonTactic.bulwark => (Icons.shield_outlined, const Color(0xFF356452)),
      DungeonTactic.control => (Icons.auto_fix_high, const Color(0xFF61537D)),
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 6, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF2ECD7),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 12 : 15, color: color),
          const SizedBox(width: 3),
          Text(
            tactic.label,
            style: TextStyle(
              color: color,
              fontSize: compact ? 10 : 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
