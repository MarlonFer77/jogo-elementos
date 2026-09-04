import 'package:battle_engine/battle_engine.dart';
import 'package:test/test.dart';

void main() {
  SkillTree buildTree() {
    return SkillTree([
      SkillNode(
        id: 'ember_mastery',
        name: 'Maestria da Brasa',
        description: 'x',
        branch: 'fogo',
        grants: Mutations.combustion,
      ),
      SkillNode(
        id: 'wildfire_path',
        name: 'Caminho do Incêndio',
        description: 'x',
        branch: 'fogo',
        prerequisites: ['ember_mastery'],
        grants: Mutations.wildfire,
      ),
      SkillNode(
        id: 'unstable_core_training',
        name: 'Treino do Núcleo Instável',
        description: 'x',
        branch: 'precisao',
        grants: Mutations.unstableCore,
      ),
      SkillNode(
        id: 'elemental_insight',
        name: 'Percepção Elemental',
        description: 'x',
        branch: 'elemental',
        grants: CombinationModifiers.propagation,
      ),
      SkillNode(
        id: 'vitality_training',
        name: 'Treino de Vitalidade',
        description: 'x',
        branch: 'vitalidade',
        grants: MaxHpBonuses.vitality,
      ),
    ]);
  }

  group('SkillProgress.canUnlock', () {
    test('a root node can be unlocked from the start', () {
      final progress = SkillProgress(buildTree());
      expect(progress.canUnlock('ember_mastery'), isTrue);
    });

    test('a node cannot be unlocked before its prerequisite', () {
      final progress = SkillProgress(buildTree());
      expect(progress.canUnlock('wildfire_path'), isFalse);
    });

    test('an unknown node id cannot be unlocked', () {
      final progress = SkillProgress(buildTree());
      expect(progress.canUnlock('ghost'), isFalse);
    });

    test('an already-unlocked node cannot be unlocked again', () {
      final progress =
          SkillProgress(buildTree()).unlock('ember_mastery');
      expect(progress.canUnlock('ember_mastery'), isFalse);
    });
  });

  group('SkillProgress.unlock', () {
    test('returns new progress without mutating the original', () {
      final tree = buildTree();
      final progress = SkillProgress(tree);

      final next = progress.unlock('ember_mastery');

      expect(next.isUnlocked('ember_mastery'), isTrue);
      expect(progress.isUnlocked('ember_mastery'), isFalse);
    });

    test('throws if the node cannot be unlocked yet', () {
      final progress = SkillProgress(buildTree());
      expect(() => progress.unlock('wildfire_path'), throwsStateError);
    });

    test('unlocks a full path one step at a time', () {
      final progress = SkillProgress(buildTree())
          .unlock('ember_mastery')
          .unlock('wildfire_path');

      expect(progress.isUnlocked('ember_mastery'), isTrue);
      expect(progress.isUnlocked('wildfire_path'), isTrue);
    });
  });

  group('SkillProgress.availableNodes', () {
    test('lists every branch root before anything is unlocked', () {
      final progress = SkillProgress(buildTree());
      expect(
        progress.availableNodes.map((n) => n.id).toSet(),
        equals({
          'ember_mastery',
          'unstable_core_training',
          'elemental_insight',
          'vitality_training',
        }),
      );
    });

    test('updates after unlocking a node', () {
      final progress =
          SkillProgress(buildTree()).unlock('ember_mastery');
      expect(
        progress.availableNodes.map((n) => n.id).toSet(),
        equals({
          'wildfire_path',
          'unstable_core_training',
          'elemental_insight',
          'vitality_training',
        }),
      );
    });
  });

  group('SkillProgress.grantedMutations', () {
    test('is empty with nothing unlocked', () {
      final progress = SkillProgress(buildTree());
      expect(progress.grantedMutations, isEmpty);
    });

    test('reflects unlock order', () {
      final progress = SkillProgress(buildTree())
          .unlock('ember_mastery')
          .unlock('wildfire_path');

      expect(
        progress.grantedMutations,
        equals([Mutations.combustion, Mutations.wildfire]),
      );
    });

    test('two players on the same tree can end up with different builds',
        () {
      final fireBuild =
          SkillProgress(buildTree()).unlock('ember_mastery');
      final precisionBuild =
          SkillProgress(buildTree()).unlock('unstable_core_training');

      expect(fireBuild.grantedMutations, equals([Mutations.combustion]));
      expect(
        precisionBuild.grantedMutations,
        equals([Mutations.unstableCore]),
      );
    });

    test('skips nodes that grant a CombinationModifier instead', () {
      final progress =
          SkillProgress(buildTree()).unlock('elemental_insight');
      expect(progress.grantedMutations, isEmpty);
    });
  });

  group('SkillProgress.grantedCombinationModifiers', () {
    test('is empty with nothing unlocked', () {
      final progress = SkillProgress(buildTree());
      expect(progress.grantedCombinationModifiers, isEmpty);
    });

    test('reflects an unlocked node granting a CombinationModifier', () {
      final progress =
          SkillProgress(buildTree()).unlock('elemental_insight');
      expect(
        progress.grantedCombinationModifiers,
        equals([CombinationModifiers.propagation]),
      );
    });

    test('skips nodes that grant a Mutation instead', () {
      final progress =
          SkillProgress(buildTree()).unlock('ember_mastery');
      expect(progress.grantedCombinationModifiers, isEmpty);
    });
  });

  group('SkillProgress.grantedMaxHpBonus', () {
    test('is 0 with nothing unlocked', () {
      final progress = SkillProgress(buildTree());
      expect(progress.grantedMaxHpBonus, equals(0));
    });

    test('reflects an unlocked MaxHpBonus node', () {
      final progress =
          SkillProgress(buildTree()).unlock('vitality_training');
      expect(progress.grantedMaxHpBonus, equals(20));
    });

    test('ignores nodes that grant a Mutation or CombinationModifier', () {
      final progress = SkillProgress(buildTree()).unlock('ember_mastery');
      expect(progress.grantedMaxHpBonus, equals(0));
    });
  });
}
