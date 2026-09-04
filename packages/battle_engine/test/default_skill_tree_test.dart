import 'package:battle_engine/battle_engine.dart';
import 'package:test/test.dart';

void main() {
  test('defaultSkillTree is a valid, non-empty tree', () {
    expect(defaultSkillTree.nodes, isNotEmpty);
  });

  test('defaultSkillTree has at least two independent branches', () {
    final branches = defaultSkillTree.nodes.map((n) => n.branch).toSet();
    expect(branches.length, greaterThanOrEqualTo(2));
  });

  test('unlocking a full path grants its mutations, ready to attach to an '
      'Ability', () {
    final progress = SkillProgress(defaultSkillTree)
        .unlock('ember_mastery')
        .unlock('wildfire_path');

    var fireball = Ability(
      id: 'fireball',
      name: 'Bola de Fogo',
      baseElements: [Elements.fire],
    );
    for (final mutation in progress.grantedMutations) {
      fireball = fireball.withMutation(mutation);
    }

    expect(fireball.mutations, equals(progress.grantedMutations));
    expect(fireball.mutations, contains(Mutations.combustion));
    expect(fireball.mutations, contains(Mutations.wildfire));
  });

  test('unlocking the elemental path grants a CombinationModifier, ready '
      'for a Build', () {
    final progress = SkillProgress(defaultSkillTree)
        .unlock('elemental_insight')
        .unlock('elemental_mastery');

    expect(
      progress.grantedCombinationModifiers,
      equals([
        CombinationModifiers.propagation,
        CombinationModifiers.volatility,
      ]),
    );
  });

  test('unlocking Treino de Vitalidade grants 20 max HP', () {
    final progress =
        SkillProgress(defaultSkillTree).unlock('vitality_training');
    expect(progress.grantedMaxHpBonus, equals(20));
  });

  test('unlocking Treino de Guarda grants Guarda', () {
    final progress =
        SkillProgress(defaultSkillTree).unlock('guard_training');
    expect(progress.grantedMutations, equals([Mutations.guard]));
  });
}
