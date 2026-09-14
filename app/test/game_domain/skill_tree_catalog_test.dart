import 'package:app/game_domain/skill_tree_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('availableSkillNodeOptions lists root nodes when nothing is unlocked', () {
    final options = availableSkillNodeOptions(const []);
    expect(options.any((o) => o.id == 'ember_mastery'), isTrue);
    expect(options.any((o) => o.id == 'wildfire_path'), isFalse); // prereq unmet
  });

  test('availableSkillNodeOptions excludes unlocked nodes and includes newly-reachable ones', () {
    final options = availableSkillNodeOptions(const ['ember_mastery']);
    expect(options.any((o) => o.id == 'ember_mastery'), isFalse);
    expect(options.any((o) => o.id == 'wildfire_path'), isTrue);
  });

  test('availableSkillNodeOptions carries display info', () {
    final options = availableSkillNodeOptions(const []);
    final ember = options.firstWhere((o) => o.id == 'ember_mastery');
    expect(ember.name, 'Maestria da Brasa');
    expect(ember.branch, 'fogo');
  });

  group('allSkillTreeNodes', () {
    test('returns all 18 nodes from defaultSkillTree with icons and prerequisites', () {
      final nodes = allSkillTreeNodes();

      expect(nodes, hasLength(18));

      final ember = nodes.firstWhere((n) => n.id == 'ember_mastery');
      expect(ember.name, 'Maestria da Brasa');
      expect(ember.branch, 'fogo');
      expect(ember.icon, '🔥');
      expect(ember.prerequisites, isEmpty);

      final wildfire = nodes.firstWhere((n) => n.id == 'wildfire_path');
      expect(wildfire.prerequisites, ['ember_mastery']);
      expect(wildfire.icon, '🌋');

      final unlockFire = nodes.firstWhere((n) => n.id == 'unlock_fire');
      expect(unlockFire.branch, 'elementos');
      expect(unlockFire.icon, '🔥');
      expect(unlockFire.prerequisites, isEmpty);
    });
  });

  group('skillTreeBranchDisplayName', () {
    test('returns the known display names', () {
      expect(skillTreeBranchDisplayName('fogo'), 'Fogo');
      expect(skillTreeBranchDisplayName('precisao'), 'Precisão');
      expect(skillTreeBranchDisplayName('elemental'), 'Elemental');
      expect(skillTreeBranchDisplayName('vitalidade'), 'Vitalidade');
      expect(skillTreeBranchDisplayName('defesa'), 'Defesa');
      expect(skillTreeBranchDisplayName('elementos'), 'Elementos');
    });

    test('falls back to the raw branch string when unknown', () {
      expect(skillTreeBranchDisplayName('mystery'), 'mystery');
    });
  });
}
