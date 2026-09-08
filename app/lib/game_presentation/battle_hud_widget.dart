import 'package:flutter/material.dart';

import '../game_domain/battle_scene_view.dart';

/// Painel de HP fixo no topo da cena, estilo jogo de luta: nome + barra de
/// HP de cada lado, com o lado ativo destacado (borda + seta). Flutter
/// puro (não Canvas do Flame) — ver
/// docs/superpowers/specs/2026-09-08-pixel-battle-arena-design.md.
class BattleHudWidget extends StatelessWidget {
  const BattleHudWidget({super.key, required this.view});

  final BattleSceneView view;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _HudPanel(
              label: view.leftLabel,
              currentHp: view.leftCurrentHp,
              maxHp: view.leftMaxHp,
              isActive: view.isLeftTurn,
              alignEnd: false,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _HudPanel(
              label: view.rightLabel,
              currentHp: view.rightCurrentHp,
              maxHp: view.rightMaxHp,
              isActive: !view.isLeftTurn,
              alignEnd: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _HudPanel extends StatelessWidget {
  const _HudPanel({
    required this.label,
    required this.currentHp,
    required this.maxHp,
    required this.isActive,
    required this.alignEnd,
  });

  final String label;
  final int currentHp;
  final int maxHp;
  final bool isActive;
  final bool alignEnd;

  Widget _buildNameRow() {
    final arrow = Text(
      alignEnd ? '◀' : '▶',
      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFB8860B)),
    );
    final nameText = Text(
      label,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF20242B)),
    );
    final children = alignEnd
        ? [nameText, if (isActive) ...[const SizedBox(width: 4), arrow]]
        : [if (isActive) ...[arrow, const SizedBox(width: 4)], nameText];
    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }

  @override
  Widget build(BuildContext context) {
    final fraction = maxHp == 0 ? 0.0 : (currentHp / maxHp).clamp(0.0, 1.0);
    final crossAlign = alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final barAlignment = alignEnd ? Alignment.centerRight : Alignment.centerLeft;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4E4),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isActive ? const Color(0xFFF4C94A) : const Color(0xFF20242B),
          width: isActive ? 3 : 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: crossAlign,
        children: [
          _buildNameRow(),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 10,
              child: Stack(
                alignment: barAlignment,
                children: [
                  Container(color: const Color(0xFF20242B)),
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(end: fraction),
                    duration: const Duration(milliseconds: 400),
                    builder: (context, value, _) {
                      return FractionallySizedBox(
                        alignment: barAlignment,
                        widthFactor: value,
                        child: Container(
                          color: value > 0.3
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFFE53935),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$currentHp/$maxHp HP',
            style: const TextStyle(fontSize: 10, color: Color(0xFF555555)),
          ),
        ],
      ),
    );
  }
}
