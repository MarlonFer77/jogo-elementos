import 'active_status.dart';
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
    description:
        'Combos aplicam queimadura: 3 de dano por 2 ações. Escudo bloqueia.',
    apply: (effect) => effect.copyWith(
      statusesToApply: [
        ...effect.statusesToApply,
        TargetedStatus(
          status: ActiveStatus(
            effect: StatusEffects.burn,
            turnsRemaining: 2,
            damagePerTick: 3,
          ),
          target: StatusTarget.opponent,
        ),
      ],
    ),
  );

  static final fragmentation = Mutation(
    id: 'fragmentation',
    name: 'Fragmentação',
    description:
        'Combos causam 80% do dano em 2 golpes. Escudo bloqueia só o primeiro; efeitos aplicam uma vez.',
    apply: (effect) => effect.copyWith(hitCount: effect.hitCount + 1),
  );

  static final wildfire = Mutation(
    id: 'wildfire',
    name: 'Incêndio',
    description:
        'Prolonga a Queimadura passiva para 3 ações, sem acumular dano por ação.',
    apply: (effect) => effect.copyWith(
      statusesToApply: [
        if (!effect.statusesToApply.any(
          (t) => t.status.effect == StatusEffects.burn,
        ))
          TargetedStatus(
            target: StatusTarget.opponent,
            status: ActiveStatus(
              effect: StatusEffects.burn,
              turnsRemaining: 3,
              damagePerTick: 3,
            ),
          ),
        for (final targeted in effect.statusesToApply)
          if (targeted.status.effect == StatusEffects.burn)
            TargetedStatus(
              target: targeted.target,
              status: ActiveStatus(
                effect: StatusEffects.burn,
                turnsRemaining: 3,
                damagePerTick: targeted.status.damagePerTick,
              ),
            )
          else
            targeted,
      ],
    ),
  );

  static final unstableCore = Mutation(
    id: 'unstable_core',
    name: 'Núcleo Instável',
    description:
        'Com AP cheio ao conjurar (inclui regeneração), combos causam +25% de dano direto. Sem sorte.',
    apply: (effect) =>
        effect.copyWith(critChanceBonus: effect.critChanceBonus + 0.25),
  );

  /// Grants Escudo to whoever plays this ability — unlike every other
  /// built-in mutation, this one protects the actor, not the opponent.
  static final guard = Mutation(
    id: 'guard',
    name: 'Guarda',
    description:
        'Conjurar um combo ergue Escudo por 2 ações, bloqueando o próximo golpe. Básicos não ativam.',
    apply: (effect) => effect.copyWith(
      statusesToApply: [
        ...effect.statusesToApply,
        TargetedStatus(
          status: ActiveStatus(effect: StatusEffects.shield, turnsRemaining: 2),
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
