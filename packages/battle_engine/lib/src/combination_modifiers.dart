import 'combination_modifier.dart';
import 'active_status.dart';
import 'targeted_status.dart';

/// Built-in combination modifiers, illustrating the design's example: the
/// same "Fogo + Vento → Tempestade Ígnea" combination coming out differently
/// depending on the build that triggered it.
class CombinationModifiers {
  CombinationModifiers._();

  static final propagation = CombinationModifier(
    id: 'propagation',
    name: 'Propagação',
    description: 'Combos: +1 de dano por tick de Queimadura e Veneno.',
    apply: (effect) => effect.copyWith(
      area: effect.area + 2,
      statusesToApply: effect.statusesToApply.map((entry) {
        final status = entry.status;
        if (entry.target != StatusTarget.opponent || status.damagePerTick == 0)
          return entry;
        return TargetedStatus(
          target: entry.target,
          status: ActiveStatus(
            effect: status.effect,
            turnsRemaining: status.turnsRemaining,
            damagePerTick: status.damagePerTick + 1,
          ),
        );
      }).toList(),
    ),
  );

  static final volatility = CombinationModifier(
    id: 'volatility',
    name: 'Instabilidade',
    description:
        'Combos com dano contínuo: +4 de dano direto, mas seus efeitos de dano duram uma ação a menos (mínimo 1).',
    apply: (effect) {
      final duration = effect.duration;
      var converted = false;
      final statuses = effect.statusesToApply.map((entry) {
        final status = entry.status;
        final turns = status.turnsRemaining;
        if (entry.target != StatusTarget.opponent ||
            status.damagePerTick == 0 ||
            turns == null ||
            turns <= 1)
          return entry;
        converted = true;
        return TargetedStatus(
          target: entry.target,
          status: ActiveStatus(
            effect: status.effect,
            turnsRemaining: turns - 1,
            damagePerTick: status.damagePerTick,
          ),
        );
      }).toList();
      return effect.copyWith(
        duration: duration == null ? null : (duration > 0 ? duration - 1 : 0),
        damage: effect.damage + (converted ? 4 : 0),
        statusesToApply: statuses,
      );
    },
  );

  static final List<CombinationModifier> all = [propagation, volatility];
}
