import 'package:flutter/material.dart';
import 'skill_tree_layout.dart';
import 'rpg_journal.dart';

/// Inspectable even while locked; unlock authority stays with the screen owner.
class SkillTreeNodeWidget extends StatelessWidget {
  const SkillTreeNodeWidget({
    super.key,
    required this.name,
    required this.icon,
    required this.state,
    required this.onTap,
    this.description,
    this.accent = RpgJournal.ink,
  });
  final String name, icon;
  final SkillTreeNodeState state;
  final VoidCallback onTap;
  final String? description;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final unlocked = state == SkillTreeNodeState.unlocked;
    final label = switch (state) {
      SkillTreeNodeState.unlocked => 'Obtida',
      SkillTreeNodeState.available => 'Consultar evolução',
      SkillTreeNodeState.locked => 'Requer anterior',
    };
    return Semantics(
      button: true,
      label: '$name · $label',
      child: Material(
        color: unlocked ? const Color(0xFFE0E6C9) : const Color(0xFFFFF8DF),
        shape: RoundedRectangleBorder(
          side: BorderSide(
            color: unlocked ? accent : RpgJournal.gold,
            width: 2,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: unlocked ? accent : RpgJournal.paper,
                    border: Border.all(color: accent, width: 2),
                  ),
                  child: Text(icon, style: const TextStyle(fontSize: 24)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        label,
                        style: TextStyle(
                          color: accent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (description != null)
                        Text(
                          description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  unlocked
                      ? Icons.check_circle_outline
                      : state == SkillTreeNodeState.locked
                      ? Icons.lock_outline
                      : Icons.chevron_right,
                  size: 20,
                  color: accent,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
