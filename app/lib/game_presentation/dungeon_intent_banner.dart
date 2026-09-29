import 'package:flutter/material.dart';
import '../game_domain/dungeon_opponent.dart';

class DungeonIntentBanner extends StatelessWidget {
  const DungeonIntentBanner({super.key, required this.intent});
  final DungeonIntent intent;

  @override
  Widget build(BuildContext context) {
    final label =
        '${intent.enraged ? 'FÚRIA · ' : ''}Próxima: ${intent.name}'
        '${intent.apCost > 0 ? ' · ${intent.apCost} AP' : ''}';
    return Tooltip(
      message: '$label\n${intent.hint}',
      child: Semantics(
        label: '$label. ${intent.hint}',
        excludeSemantics: true,
        child: Container(
          margin: const EdgeInsets.only(bottom: 3),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
          decoration: BoxDecoration(
            color: intent.enraged
                ? const Color(0xFFF2D3B1)
                : const Color(0xFFE8E0C4),
            border: Border(
              left: BorderSide(
                color: intent.enraged
                    ? const Color(0xFF9D3928)
                    : const Color(0xFF6C7451),
                width: 3,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                intent.thawing
                    ? Icons.ac_unit
                    : intent.defending
                    ? Icons.shield_outlined
                    : intent.attackId != null
                    ? Icons.auto_fix_high
                    : Icons.flash_on,
                size: 16,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    color: Color(0xFF302C25),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
