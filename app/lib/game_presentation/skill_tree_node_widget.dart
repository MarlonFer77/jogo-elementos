import 'package:flutter/material.dart';

import 'skill_tree_layout.dart';

/// Um nó da árvore de habilidades — círculo com ícone, cor de acordo com
/// o estado (travado/disponível/desbloqueado). Sempre tocável: é o painel
/// de detalhe aberto por `onTap` que decide o que mostrar pra cada
/// estado — ver `SkillTreeScreen`.
class SkillTreeNodeWidget extends StatelessWidget {
  const SkillTreeNodeWidget({
    super.key,
    required this.name,
    required this.icon,
    required this.state,
    required this.onTap,
  });

  final String name;
  final String icon;
  final SkillTreeNodeState state;
  final VoidCallback onTap;

  Color get _color {
    return state == SkillTreeNodeState.unlocked
        ? const Color(0xFFF4C94A)
        : const Color(0xFFF4F4E4);
  }

  double get _opacity => state == SkillTreeNodeState.locked ? 0.4 : 1.0;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: _opacity,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _color,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF2B2B2B), width: 3),
              ),
              child: Text(icon, style: const TextStyle(fontSize: 24)),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 72,
              child: Text(
                name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  color: Color(0xFF2B2B2B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
