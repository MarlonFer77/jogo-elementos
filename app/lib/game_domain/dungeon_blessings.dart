import 'package:battle_engine/battle_engine.dart';

enum BlessingRole { offense, defense, energy }

/// Temporary encounter grants. Never added to the permanent skill tree/profile.
class DungeonBlessing {
  const DungeonBlessing({
    required this.id,
    required this.altar,
    required this.name,
    required this.description,
    required this.role,
    this.initialAp = 0,
    this.extraApCapacity = 0,
    this.openingStatuses = const [],
    this.mutation,
    this.modifier,
  });
  final String id, name, description;
  final int altar, initialAp, extraApCapacity;
  final BlessingRole role;
  final List<ActiveStatus> openingStatuses;
  final Mutation? mutation;
  final CombinationModifier? modifier;
}

abstract final class DungeonBlessings {
  static const milestones = [3, 6, 9];

  static CombinationModifier _comboDamage(
    String id,
    int elements,
    int Function(int) damage,
  ) {
    final recipes = defaultCombinationBook.combinations
        .where((c) => c.elements.length == elements)
        .map((c) => c.resultId)
        .toSet();
    return CombinationModifier(
      id: id,
      name: id,
      description: '',
      apply: (effect) => recipes.contains(effect.id) && effect.damage > 0
          ? effect.copyWith(damage: damage(effect.damage))
          : effect,
    );
  }

  static Mutation _comboStatus(
    String id,
    StatusEffect status,
    StatusTarget target,
  ) => Mutation(
    id: id,
    name: id,
    description: '',
    apply: (effect) => effect.copyWith(
      statusesToApply: [
        ...effect.statusesToApply,
        TargetedStatus(
          target: target,
          status: ActiveStatus(effect: status, turnsRemaining: 1),
        ),
      ],
    ),
  );

  static final all = List<DungeonBlessing>.unmodifiable([
    DungeonBlessing(
      id: 'opening_ember',
      altar: 3,
      name: 'Ímpeto das Brasas',
      role: BlessingRole.offense,
      description:
          'Comece cada sala com Fortalecimento: +25% de dano direto na primeira ação. Defender também consome essa abertura.',
      openingStatuses: [
        ActiveStatus(effect: StatusEffects.buff, turnsRemaining: 1),
      ],
    ),
    DungeonBlessing(
      id: 'pilgrim_shield',
      altar: 3,
      name: 'Guarda do Peregrino',
      role: BlessingRole.defense,
      description:
          'Comece cada sala com Escudo por 2 ações. Bloqueia um golpe, não o dano contínuo.',
      openingStatuses: [
        ActiveStatus(effect: StatusEffects.shield, turnsRemaining: 2),
      ],
    ),
    const DungeonBlessing(
      id: 'first_spark',
      altar: 3,
      name: 'Primeira Centelha',
      role: BlessingRole.energy,
      initialAp: 1,
      description:
          'Comece cada sala com +1 AP. Antecipe seu primeiro combo; o custo e a regeneração não mudam.',
    ),
    DungeonBlessing(
      id: 'twin_runes',
      altar: 6,
      name: 'Runas Gêmeas',
      role: BlessingRole.offense,
      description:
          'Combos de 2 elementos ganham +3 de dano-base direto. Combos de 3 e habilidades sem dano não recebem o bônus.',
      modifier: _comboDamage('dungeon_twin_runes', 2, (damage) => damage + 3),
    ),
    DungeonBlessing(
      id: 'woven_guard',
      altar: 6,
      name: 'Manto de Runas',
      role: BlessingRole.defense,
      description:
          'Um combo concluído prepara Defesa: próximo golpe direto −50%. Não acumula redução nem ativa com básico ou selo falho.',
      mutation: _comboStatus(
        'dungeon_woven_guard',
        StatusEffects.guard,
        StatusTarget.actor,
      ),
    ),
    const DungeonBlessing(
      id: 'deep_reserve',
      altar: 6,
      name: 'Reserva Profunda',
      role: BlessingRole.energy,
      extraApCapacity: 1,
      description:
          'Limite de AP: 5 → 6. Reserve energia para combos caros ou Choque. Não enche AP; Concentração passa a exigir a reserva de 6 cheia.',
    ),
    DungeonBlessing(
      id: 'trinity_echo',
      altar: 9,
      name: 'Eco da Trindade',
      role: BlessingRole.offense,
      description:
          'Combos de 3 elementos causam +20% de dano direto antes da qualidade do selo e da defesa. Exige uma build com combos triplos.',
      modifier: _comboDamage(
        'dungeon_trinity_echo',
        3,
        (damage) => (damage * 1.2).ceil(),
      ),
    ),
    DungeonBlessing(
      id: 'quiet_oath',
      altar: 9,
      name: 'Voto do Crepúsculo',
      role: BlessingRole.defense,
      description:
          'Combos concluídos aplicam Enfraquecimento: inimigo causa −25% de dano direto na próxima ação. Escudo bloqueia a aplicação.',
      mutation: _comboStatus(
        'dungeon_quiet_oath',
        StatusEffects.debuff,
        StatusTarget.opponent,
      ),
    ),
    const DungeonBlessing(
      id: 'last_breath',
      altar: 9,
      name: 'Fôlego da Ruína',
      role: BlessingRole.energy,
      initialAp: 2,
      description:
          'Comece cada sala restante com +2 AP. Soma com Primeira Centelha. Sem aumentar o limite ou dar energia a cada turno.',
    ),
  ]);

  static DungeonBlessing? byId(String id) =>
      all.where((b) => b.id == id).firstOrNull;
  static List<DungeonBlessing> offers(int altar) =>
      List.unmodifiable(all.where((b) => b.altar == altar));
}
