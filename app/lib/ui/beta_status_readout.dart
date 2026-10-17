import 'package:flutter/material.dart';
import '../game_domain/beta_session.dart';

/// Read-only effects: timers come from simulation, never a separate UI clock.
class BetaStatusReadout extends StatelessWidget {
  const BetaStatusReadout({
    super.key,
    required this.run,
    required this.critical,
  });
  final BetaSession run;
  final bool critical;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          critical
              ? 'VIDA BAIXA · Água cura ao acertar'
              : 'Nv. ${run.level} · ${run.remaining} inimigos · ${run.xp}/${run.nextLevelXp} XP',
          key: const ValueKey('beta-status'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10,
            color: critical ? const Color(0xFFFFC4A1) : const Color(0xFFD0D5B7),
          ),
        ),
        Wrap(
          spacing: 4,
          runSpacing: 2,
          children: [
            if (run.burnTime > 0)
              _badge(
                'burn',
                Icons.local_fire_department,
                '${run.burnTime.ceil()}s',
                const Color(0xFFFFB88C),
                'Queimadura: 2 HP por segundo. Restam ${run.burnTime.ceil()}s.',
              ),
            if (run.curseTime > 0)
              _badge(
                'curse',
                Icons.visibility_off,
                '${run.curseTime.ceil()}s',
                const Color(0xFFD6B5EF),
                'Maldição: regeneração de mana pela metade. Restam ${run.curseTime.ceil()}s.',
              ),
            if (run.blessingTime > 0)
              _badge(
                'blessing',
                Icons.auto_fix_high,
                '${run.blessingTime.ceil()}s',
                const Color(0xFFF3D99A),
                'Excalibur: +3 no próximo corte. Errar também consome a bênção. '
                    'Restam ${run.blessingTime.ceil()}s.',
              ),
            if (run.runicBladeTime > 0)
              _badge(
                'rune',
                Icons.flash_on,
                '${run.runicBladeTime.ceil()}s',
                const Color(0xFFB4D7ED),
                'Lâmina Rúnica: próximo corte +8. Restam ${run.runicBladeTime.ceil()}s.',
              ),
            if (run.protection > 0)
              _badge(
                'shield',
                Icons.shield_outlined,
                '${run.protection.ceil()}s',
                const Color(0xFFDED2AB),
                'Proteção: reduz dano de impacto pela metade. Restam ${run.protection.ceil()}s.',
              ),
            if (run.wardTime > 0)
              _badge(
                'ward',
                Icons.verified_user_outlined,
            'OK',
                const Color(0xFFB2DFCA),
                'Perseu impediu um efeito negativo. O dano de impacto não foi bloqueado.',
              ),
          ],
        ),
      ],
    );
  }

  Widget _badge(
    String id,
    IconData icon,
    String timer,
    Color color,
    String hint,
  ) => Tooltip(
    message: hint,
    excludeFromSemantics: true,
    child: Semantics(
      label: hint,
      child: ExcludeSemantics(
        child: Container(
          key: ValueKey('beta-effect-$id'),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF1C302B),
            border: Border(bottom: BorderSide(color: color)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 2),
              Text(timer, style: TextStyle(fontSize: 10, color: color)),
            ],
          ),
        ),
      ),
    ),
  );
}
