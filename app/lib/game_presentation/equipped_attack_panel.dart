import 'package:flutter/material.dart';

import '../game_domain/attack_catalog.dart';
import '../game_domain/element_catalog.dart';
import 'pixel_menu_button.dart';

/// Compact slots; availability and execution remain in Game Domain.
class EquippedAttackPanel extends StatelessWidget {
  const EquippedAttackPanel({
    super.key,
    required this.attacks,
    required this.selectedId,
    required this.unavailableReason,
    required this.onSelect,
    required this.onExecute,
  });

  final List<AttackOption> attacks;
  final String? selectedId;
  final String? Function(String) unavailableReason;
  final ValueChanged<String> onSelect;
  final VoidCallback onExecute;

  @override
  Widget build(BuildContext context) {
    final elements = const ElementCatalog().all();
    final selected = attacks.where((a) => a.id == selectedId).firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'ATAQUES EQUIPADOS',
          style: TextStyle(
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        for (var slot = 0; slot < 3; slot++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: slot >= attacks.length
                ? const Text(
                    '— Descubra um combo',
                    style: TextStyle(color: Colors.black54),
                  )
                : Builder(
                    builder: (context) {
                      final attack = attacks[slot];
                      final reason = unavailableReason(attack.id);
                      return Semantics(
                        selected: selectedId == attack.id,
                        child: OutlinedButton(
                          key: ValueKey('attack-${attack.id}'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: reason == null
                                ? const Color(0xFF2B2B2B)
                                : Colors.black54,
                            backgroundColor: selectedId == attack.id
                                ? const Color(0xFFF4C94A)
                                : const Color(0xFFF4F4E4),
                            side: const BorderSide(
                              color: Color(0xFF2B2B2B),
                              width: 2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          onPressed: () => onSelect(attack.id),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        attack.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        elements
                                            .where(
                                              (e) => attack.elementIds.contains(
                                                e.id,
                                              ),
                                            )
                                            .map((e) => e.symbol)
                                            .join(' + '),
                                      ),
                                      if (reason != null) Text(reason),
                                    ],
                                  ),
                                ),
                                Text('${attack.apCost} AP'),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        if (selected != null) ...[
          Text(selected.description),
          const SizedBox(height: 8),
          PixelMenuButton(
            label: 'Usar ataque · ${selected.apCost} AP',
            primary: true,
            onPressed: unavailableReason(selected.id) == null
                ? onExecute
                : null,
          ),
        ],
      ],
    );
  }
}
