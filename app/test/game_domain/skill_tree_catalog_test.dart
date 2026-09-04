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
}
