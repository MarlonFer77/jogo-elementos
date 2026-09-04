import 'package:battle_engine/battle_engine.dart';
import 'package:test/test.dart';

void main() {
  SkillNode node(
    String id, {
    List<String> prerequisites = const [],
    String branch = 'fogo',
  }) {
    return SkillNode(
      id: id,
      name: id,
      description: id,
      branch: branch,
      prerequisites: prerequisites,
      grants: Mutations.combustion,
    );
  }

  group('SkillTree construction', () {
    test('rejects duplicate ids', () {
      expect(
        () => SkillTree([node('a'), node('a')]),
        throwsArgumentError,
      );
    });

    test('rejects a prerequisite that does not exist', () {
      expect(
        () => SkillTree([node('a', prerequisites: ['ghost'])]),
        throwsArgumentError,
      );
    });

    test('rejects a direct cycle (a requires b, b requires a)', () {
      expect(
        () => SkillTree([
          node('a', prerequisites: ['b']),
          node('b', prerequisites: ['a']),
        ]),
        throwsArgumentError,
      );
    });

    test('rejects a self-referencing node', () {
      expect(
        () => SkillTree([node('a', prerequisites: ['a'])]),
        throwsArgumentError,
      );
    });

    test('accepts a valid DAG with a convergence point', () {
      final tree = SkillTree([
        node('a'),
        node('b'),
        node('c', prerequisites: ['a', 'b']),
      ]);
      expect(tree.nodes, hasLength(3));
    });
  });

  group('SkillTree.nodeById', () {
    test('returns the matching node', () {
      final tree = SkillTree([node('a')]);
      expect(tree.nodeById('a'), equals(node('a')));
    });

    test('returns null for an unknown id', () {
      final tree = SkillTree([node('a')]);
      expect(tree.nodeById('ghost'), isNull);
    });
  });

  group('SkillTree.availableFrom', () {
    test('root nodes are available with nothing unlocked', () {
      final tree = SkillTree([
        node('a'),
        node('b', prerequisites: ['a']),
      ]);
      final available = tree.availableFrom({});
      expect(available.map((n) => n.id), equals(['a']));
    });

    test('a node becomes available once its prerequisite is unlocked', () {
      final tree = SkillTree([
        node('a'),
        node('b', prerequisites: ['a']),
      ]);
      final available = tree.availableFrom({'a'});
      expect(available.map((n) => n.id), equals(['b']));
    });

    test('two independent branches are both available at the root', () {
      final tree = SkillTree([
        node('fire_a', branch: 'fogo'),
        node('precision_a', branch: 'precisao'),
      ]);
      final available = tree.availableFrom({});
      expect(
        available.map((n) => n.id).toSet(),
        equals({'fire_a', 'precision_a'}),
      );
    });

    test('an already-unlocked node is not listed as available', () {
      final tree = SkillTree([node('a')]);
      expect(tree.availableFrom({'a'}), isEmpty);
    });
  });
}
