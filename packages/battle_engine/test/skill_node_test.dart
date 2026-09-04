import 'package:battle_engine/battle_engine.dart';
import 'package:test/test.dart';

void main() {
  group('SkillNode', () {
    test('two nodes with the same id are equal', () {
      final a = SkillNode(
        id: 'x',
        name: 'X',
        description: 'a',
        branch: 'fogo',
        grants: Mutations.combustion,
      );
      final b = SkillNode(
        id: 'x',
        name: 'Outro nome',
        description: 'b',
        branch: 'precisao',
        grants: Mutations.wildfire,
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('defaults to no prerequisites', () {
      final node = SkillNode(
        id: 'x',
        name: 'X',
        description: 'a',
        branch: 'fogo',
        grants: Mutations.combustion,
      );
      expect(node.prerequisites, isEmpty);
    });
  });
}
