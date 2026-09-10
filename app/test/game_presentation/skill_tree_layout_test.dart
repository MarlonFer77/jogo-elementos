import 'package:app/game_domain/skill_tree_catalog.dart';
import 'package:app/game_presentation/skill_tree_layout.dart';
import 'package:flutter_test/flutter_test.dart';

const _a = SkillTreeNodeOption(
  id: 'a',
  name: 'A',
  description: '',
  branch: 'x',
  prerequisites: [],
  icon: '🔥',
);
const _b = SkillTreeNodeOption(
  id: 'b',
  name: 'B',
  description: '',
  branch: 'x',
  prerequisites: ['a'],
  icon: '🔥',
);
const _c = SkillTreeNodeOption(
  id: 'c',
  name: 'C',
  description: '',
  branch: 'x',
  prerequisites: ['b'],
  icon: '🔥',
);

void main() {
  group('orderBranchNodes', () {
    test('returns a single node unchanged', () {
      expect(orderBranchNodes([_a]), [_a]);
    });

    test('places the prerequisite before the node that depends on it', () {
      expect(orderBranchNodes([_b, _a]), [_a, _b]);
    });

    test('orders a chain of three regardless of input order', () {
      expect(orderBranchNodes([_c, _a, _b]), [_a, _b, _c]);
    });
  });

  group('skillTreeNodeState', () {
    test('a node with no prerequisites and not unlocked is available', () {
      expect(skillTreeNodeState(_a, const []), SkillTreeNodeState.available);
    });

    test('a node whose prerequisite is not met is locked', () {
      expect(skillTreeNodeState(_b, const []), SkillTreeNodeState.locked);
    });

    test('a node whose prerequisite is met and is not unlocked is available', () {
      expect(skillTreeNodeState(_b, const ['a']), SkillTreeNodeState.available);
    });

    test('a node already in unlockedNodeIds is unlocked', () {
      expect(skillTreeNodeState(_a, const ['a']), SkillTreeNodeState.unlocked);
    });
  });
}
