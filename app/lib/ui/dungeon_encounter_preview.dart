import 'package:flutter/material.dart';
import '../game_domain/combination_catalog.dart';
import '../game_domain/dungeon_catalog.dart';
import '../game_domain/element_catalog.dart';
import '../game_presentation/creature_portrait.dart';
import '../game_presentation/dungeon_tactic_badge.dart';
import '../game_presentation/pixel_content_panel.dart';

class DungeonEncounterPreview extends StatelessWidget {
  const DungeonEncounterPreview({
    super.key,
    required this.room,
    required this.index,
    required this.onElements,
    required this.onAttacks,
  });
  final DungeonRoom room;
  final int index;
  final VoidCallback? onElements, onAttacks;

  @override
  Widget build(BuildContext context) => PixelContentPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'PRÓXIMO · SALA ${index + 1}/10',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
            ),
            if (room.tactic != null) DungeonTacticBadge(tactic: room.tactic!),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            CreaturePortrait(appearance: room.appearance, label: room.name),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    room.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    '${room.hp} HP · ${room.initialAp} AP inicial · +${room.xp} XP',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Repertório do inimigo',
              icon: const Icon(Icons.info_outline),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: const Color(0xFFF8F2DA),
                  title: Text(room.name),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (room.tactic != null)
                          DungeonTacticBadge(tactic: room.tactic!),
                        const SizedBox(height: 8),
                        Text(
                          'Elementos: ${const ElementCatalog().all().where((e) => room.elements.contains(e.id)).map((e) => e.name).join(' · ')}',
                        ),
                        const SizedBox(height: 8),
                        for (final id in room.attacks)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              '${const CombinationCatalog().byId(id)!.name}\n${const CombinationCatalog().byId(id)!.description}',
                            ),
                          ),
                        Text(room.hint),
                        const SizedBox(height: 8),
                        const Text(
                          'A intenção anuncia a próxima ação. Congelar, Silenciar ou drenar AP pode interromper o plano; ele não escolhe um golpe mais forte depois de você agir.',
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Entendi'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        Text(
          room.hint,
          style: const TextStyle(fontSize: 12, color: Color(0xFF484635)),
        ),
        Wrap(
          spacing: 8,
          children: [
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF365443),
              ),
              onPressed: onElements,
              icon: const Icon(Icons.tune, size: 16),
              label: const Text('Elementos'),
            ),
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF365443),
              ),
              onPressed: onAttacks,
              icon: const Icon(Icons.auto_fix_high, size: 16),
              label: const Text('Habilidades'),
            ),
          ],
        ),
      ],
    ),
  );
}
