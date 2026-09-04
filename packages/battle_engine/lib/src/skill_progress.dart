import 'combination_modifier.dart';
import 'max_hp_bonus.dart';
import 'mutation.dart';
import 'skill_node.dart';
import 'skill_tree.dart';

/// Tracks which [SkillNode]s a single build has unlocked in a [SkillTree].
/// Immutable — [unlock] returns a new [SkillProgress]. Two players can use
/// the same tree and end up with completely different unlocked nodes, and
/// therefore different [grantedMutations]/[grantedCombinationModifiers]/
/// [grantedMaxHpBonus].
class SkillProgress {
  final SkillTree tree;
  final List<String> unlockedNodeIds;

  SkillProgress(this.tree, {List<String> unlockedNodeIds = const []})
      : unlockedNodeIds = List.unmodifiable(unlockedNodeIds);

  bool isUnlocked(String nodeId) => unlockedNodeIds.contains(nodeId);

  /// Whether [nodeId] exists, isn't unlocked yet, and has every prerequisite
  /// already unlocked.
  bool canUnlock(String nodeId) {
    final node = tree.nodeById(nodeId);
    if (node == null || isUnlocked(nodeId)) return false;
    return node.prerequisites.every(isUnlocked);
  }

  /// Returns new progress with [nodeId] unlocked.
  SkillProgress unlock(String nodeId) {
    if (!canUnlock(nodeId)) {
      throw StateError('Cannot unlock "$nodeId" yet');
    }
    return SkillProgress(tree, unlockedNodeIds: [...unlockedNodeIds, nodeId]);
  }

  /// Nodes currently unlockable: prerequisites met, not yet unlocked.
  List<SkillNode> get availableNodes =>
      tree.availableFrom(unlockedNodeIds.toSet());

  /// Mutations granted by unlocked nodes (nodes that grant a
  /// [CombinationModifier] or [MaxHpBonus] instead are skipped here), in
  /// unlock order, deduplicated by id.
  List<Mutation> get grantedMutations {
    return _grantedOfType<Mutation>((grant) => grant.id);
  }

  /// Combination modifiers granted by unlocked nodes (nodes that grant a
  /// [Mutation] or [MaxHpBonus] instead are skipped here), in unlock order,
  /// deduplicated by id.
  List<CombinationModifier> get grantedCombinationModifiers {
    return _grantedOfType<CombinationModifier>((grant) => grant.id);
  }

  /// Sum of every [MaxHpBonus] granted by unlocked nodes (nodes that grant
  /// a [Mutation] or [CombinationModifier] instead are skipped),
  /// deduplicated by id before summing.
  int get grantedMaxHpBonus {
    return _grantedOfType<MaxHpBonus>((grant) => grant.id)
        .fold<int>(0, (sum, bonus) => sum + bonus.bonus);
  }

  List<T> _grantedOfType<T>(String Function(T) idOf) {
    final seenIds = <String>{};
    final result = <T>[];
    for (final nodeId in unlockedNodeIds) {
      final grant = tree.nodeById(nodeId)!.grants;
      if (grant is T) {
        final typed = grant as T;
        if (seenIds.add(idOf(typed))) {
          result.add(typed);
        }
      }
    }
    return result;
  }
}
