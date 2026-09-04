import 'active_status.dart';
import 'field_effect.dart';
import 'mutation.dart';
import 'status_effects.dart';
import 'targeted_status.dart';

/// Built-in mutations, from the game's design example (Bola de Fogo:
/// Combustão, Fragmentação, Incêndio, Núcleo Instável). Data-driven — new
/// mutations are added as entries here, not as new resolver logic.
class Mutations {
  Mutations._();

  static final combustion = Mutation(
    id: 'combustion',
    name: 'Combustão',
    description: 'Aplica queimadura ao alvo (8 de dano por 2 turnos).',
    apply: (effect) => effect.copyWith(
      statusesToApply: [
        ...effect.statusesToApply,
        TargetedStatus(
          status: ActiveStatus(
            effect: StatusEffects.burn,
            turnsRemaining: 2,
            damagePerTick: 8,
          ),
          target: StatusTarget.opponent,
        ),
      ],
    ),
  );

  static final fragmentation = Mutation(
    id: 'fragmentation',
    name: 'Fragmentação',
    description: 'Divide o ataque em múltiplos golpes.',
    apply: (effect) => effect.copyWith(hitCount: effect.hitCount + 1),
  );

  static final wildfire = Mutation(
    id: 'wildfire',
    name: 'Incêndio',
    description: 'Cria uma área de fogo no campo.',
    apply: (effect) => effect.copyWith(
      fieldEffect: const FieldEffect(
        id: 'fire_zone',
        name: 'Área em Chamas',
        description: 'Zona de fogo persistente no campo.',
      ),
    ),
  );

  static final unstableCore = Mutation(
    id: 'unstable_core',
    name: 'Núcleo Instável',
    description: 'Aumenta a chance de crítico.',
    apply: (effect) => effect.copyWith(
      critChanceBonus: effect.critChanceBonus + 0.15,
    ),
  );

  /// Grants Escudo to whoever plays this ability — unlike every other
  /// built-in mutation, this one protects the actor, not the opponent.
  static final guard = Mutation(
    id: 'guard',
    name: 'Guarda',
    description: 'Ergue um escudo que bloqueia o próximo dano de combo '
        'recebido.',
    apply: (effect) => effect.copyWith(
      statusesToApply: [
        ...effect.statusesToApply,
        TargetedStatus(
          status: ActiveStatus(effect: StatusEffects.shield),
          target: StatusTarget.actor,
        ),
      ],
    ),
  );

  static final List<Mutation> all = [
    combustion,
    fragmentation,
    wildfire,
    unstableCore,
    guard,
  ];
}
