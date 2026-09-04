import 'skill_node.dart';

/// A data-driven graph of [SkillNode]s. Nodes reference their prerequisites
/// by id, so the tree can branch (several nodes available at once from
/// different paths) and converge (a node requiring nodes from more than one
/// branch). Validated to be free of unknown references and cycles.
class SkillTree {
  final Map<String, SkillNode> _nodesById;

  SkillTree(Iterable<SkillNode> nodes) : _nodesById = _index(nodes) {
    _checkNoCycles(_nodesById);
  }

  List<SkillNode> get nodes => List.unmodifiable(_nodesById.values);

  SkillNode? nodeById(String id) => _nodesById[id];

  /// Nodes whose prerequisites are all in [unlockedIds] and that are not
  /// themselves already in [unlockedIds].
  List<SkillNode> availableFrom(Set<String> unlockedIds) {
    return nodes
        .where((node) => !unlockedIds.contains(node.id))
        .where((node) => node.prerequisites.every(unlockedIds.contains))
        .toList();
  }

  static Map<String, SkillNode> _index(Iterable<SkillNode> nodes) {
    final list = List<SkillNode>.of(nodes);
    final map = <String, SkillNode>{};
    for (final node in list) {
      if (map.containsKey(node.id)) {
        throw ArgumentError.value(nodes, 'nodes', 'duplicate id "${node.id}"');
      }
      map[node.id] = node;
    }
    for (final node in list) {
      for (final prerequisiteId in node.prerequisites) {
        if (!map.containsKey(prerequisiteId)) {
          throw ArgumentError.value(
            nodes,
            'nodes',
            '"${node.id}" references unknown prerequisite '
                '"$prerequisiteId"',
          );
        }
      }
    }
    return Map.unmodifiable(map);
  }

  static void _checkNoCycles(Map<String, SkillNode> nodesById) {
    const unvisited = 0;
    const visiting = 1;
    const visited = 2;
    final state = <String, int>{for (final id in nodesById.keys) id: unvisited};

    void visit(String id) {
      if (state[id] == visited) return;
      if (state[id] == visiting) {
        throw ArgumentError('Skill tree has a cycle involving "$id"');
      }
      state[id] = visiting;
      for (final prerequisiteId in nodesById[id]!.prerequisites) {
        visit(prerequisiteId);
      }
      state[id] = visited;
    }

    for (final id in nodesById.keys) {
      visit(id);
    }
  }
}
