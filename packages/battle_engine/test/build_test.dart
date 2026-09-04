import 'package:battle_engine/battle_engine.dart';
import 'package:test/test.dart';

void main() {
  Ability fireball({List<Mutation> mutations = const []}) {
    var ability = Ability(
      id: 'fireball',
      name: 'Bola de Fogo',
      baseElements: [Elements.fire],
    );
    for (final mutation in mutations) {
      ability = ability.withMutation(mutation);
    }
    return ability;
  }

  group('Build construction', () {
    test('throws if no abilities are given', () {
      final progress = SkillProgress(defaultSkillTree);
      expect(
        () => Build(
          id: 'b1',
          name: 'Build',
          skillProgress: progress,
          abilities: [],
        ),
        throwsArgumentError,
      );
    });

    test('throws on duplicate ability ids', () {
      final progress = SkillProgress(defaultSkillTree);
      expect(
        () => Build(
          id: 'b1',
          name: 'Build',
          skillProgress: progress,
          abilities: [fireball(), fireball()],
        ),
        throwsArgumentError,
      );
    });

    test('throws if an ability uses a mutation that is not unlocked', () {
      final progress = SkillProgress(defaultSkillTree);
      expect(
        () => Build(
          id: 'b1',
          name: 'Build',
          skillProgress: progress,
          abilities: [
            fireball(mutations: [Mutations.combustion]),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('accepts an ability using an unlocked mutation', () {
      final progress =
          SkillProgress(defaultSkillTree).unlock('ember_mastery');
      final build = Build(
        id: 'b1',
        name: 'Build',
        skillProgress: progress,
        abilities: [
          fireball(mutations: [Mutations.combustion]),
        ],
      );
      expect(build.abilities, hasLength(1));
    });

    test('accepts abilities with no mutations regardless of progress', () {
      final progress = SkillProgress(defaultSkillTree);
      final build = Build(
        id: 'b1',
        name: 'Build',
        skillProgress: progress,
        abilities: [fireball()],
      );
      expect(build.abilities, hasLength(1));
    });
  });

  group('Build.abilityById', () {
    test('returns the matching ability', () {
      final progress = SkillProgress(defaultSkillTree);
      final build = Build(
        id: 'b1',
        name: 'Build',
        skillProgress: progress,
        abilities: [fireball()],
      );
      expect(build.abilityById('fireball'), equals(fireball()));
    });

    test('returns null for an unknown id', () {
      final progress = SkillProgress(defaultSkillTree);
      final build = Build(
        id: 'b1',
        name: 'Build',
        skillProgress: progress,
        abilities: [fireball()],
      );
      expect(build.abilityById('ghost'), isNull);
    });
  });

  group('Build.withAbility', () {
    test('appends a new ability without mutating the original build', () {
      final progress = SkillProgress(defaultSkillTree);
      final build = Build(
        id: 'b1',
        name: 'Build',
        skillProgress: progress,
        abilities: [fireball()],
      );
      final iceShard = Ability(
        id: 'ice_shard',
        name: 'Lasca de Gelo',
        baseElements: [Elements.ice],
      );

      final next = build.withAbility(iceShard);

      expect(
        next.abilities.map((a) => a.id),
        equals(['fireball', 'ice_shard']),
      );
      expect(build.abilities.map((a) => a.id), equals(['fireball']));
    });

    test('replaces the existing ability with the same id', () {
      final progress =
          SkillProgress(defaultSkillTree).unlock('ember_mastery');
      final build = Build(
        id: 'b1',
        name: 'Build',
        skillProgress: progress,
        abilities: [fireball()],
      );

      final next = build.withAbility(
        fireball(mutations: [Mutations.combustion]),
      );

      expect(next.abilities, hasLength(1));
      expect(
        next.abilities.single.mutations,
        equals([Mutations.combustion]),
      );
    });

    test('re-validates and throws if the replacement uses a locked '
        'mutation', () {
      final progress = SkillProgress(defaultSkillTree);
      final build = Build(
        id: 'b1',
        name: 'Build',
        skillProgress: progress,
        abilities: [fireball()],
      );

      expect(
        () => build.withAbility(
          fireball(mutations: [Mutations.combustion]),
        ),
        throwsArgumentError,
      );
    });
  });

  group('Build.withSkillProgress', () {
    test('re-validates against the new progress', () {
      final unlocked =
          SkillProgress(defaultSkillTree).unlock('ember_mastery');
      final build = Build(
        id: 'b1',
        name: 'Build',
        skillProgress: unlocked,
        abilities: [
          fireball(mutations: [Mutations.combustion]),
        ],
      );

      expect(
        () => build.withSkillProgress(SkillProgress(defaultSkillTree)),
        throwsArgumentError,
      );
    });
  });

  group('Build.combinationModifiers', () {
    test('defaults to empty', () {
      final progress = SkillProgress(defaultSkillTree);
      final build = Build(
        id: 'b1',
        name: 'Build',
        skillProgress: progress,
        abilities: [fireball()],
      );
      expect(build.combinationModifiers, isEmpty);
    });

    test('throws if a modifier is not unlocked', () {
      final progress = SkillProgress(defaultSkillTree);
      expect(
        () => Build(
          id: 'b1',
          name: 'Build',
          skillProgress: progress,
          abilities: [fireball()],
          combinationModifiers: [CombinationModifiers.propagation],
        ),
        throwsArgumentError,
      );
    });

    test('accepts an unlocked modifier', () {
      final progress = SkillProgress(
        defaultSkillTree,
      ).unlock('elemental_insight');
      final build = Build(
        id: 'b1',
        name: 'Build',
        skillProgress: progress,
        abilities: [fireball()],
        combinationModifiers: [CombinationModifiers.propagation],
      );
      expect(build.combinationModifiers, equals([
        CombinationModifiers.propagation,
      ]));
    });
  });

  group('Build.withCombinationModifier', () {
    test('appends without mutating the original build', () {
      final progress = SkillProgress(
        defaultSkillTree,
      ).unlock('elemental_insight');
      final build = Build(
        id: 'b1',
        name: 'Build',
        skillProgress: progress,
        abilities: [fireball()],
      );

      final next = build.withCombinationModifier(
        CombinationModifiers.propagation,
      );

      expect(
        next.combinationModifiers,
        equals([CombinationModifiers.propagation]),
      );
      expect(build.combinationModifiers, isEmpty);
    });

    test('throws if the modifier is not unlocked', () {
      final progress = SkillProgress(defaultSkillTree);
      final build = Build(
        id: 'b1',
        name: 'Build',
        skillProgress: progress,
        abilities: [fireball()],
      );

      expect(
        () => build.withCombinationModifier(CombinationModifiers.propagation),
        throwsArgumentError,
      );
    });
  });

  test('two players can build completely differently from the same tree '
      'and element', () {
    final fireBuild = Build(
      id: 'fire',
      name: 'Piromante',
      skillProgress:
          SkillProgress(defaultSkillTree).unlock('ember_mastery'),
      abilities: [
        fireball(mutations: [Mutations.combustion]),
      ],
    );

    final precisionBuild = Build(
      id: 'precision',
      name: 'Instável',
      skillProgress: SkillProgress(
        defaultSkillTree,
      ).unlock('unstable_core_training'),
      abilities: [
        fireball(mutations: [Mutations.unstableCore]),
      ],
    );

    expect(
      fireBuild.abilityById('fireball')!.mutations,
      equals([Mutations.combustion]),
    );
    expect(
      precisionBuild.abilityById('fireball')!.mutations,
      equals([Mutations.unstableCore]),
    );
  });
}
