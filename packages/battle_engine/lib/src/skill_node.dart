import 'skill_grant.dart';

/// A node in a [SkillTree]. Unlocking it grants [grants] (a [SkillGrant] —
/// a [Mutation] or a [CombinationModifier]) once every id in
/// [prerequisites] is already unlocked. [branch] groups nodes into the
/// tree's different paths (e.g. "fogo", "precisão").
class SkillNode {
  final String id;
  final String name;
  final String description;
  final String branch;
  final List<String> prerequisites;
  final SkillGrant grants;

  SkillNode({
    required this.id,
    required this.name,
    required this.description,
    required this.branch,
    List<String> prerequisites = const [],
    required this.grants,
  }) : prerequisites = List.unmodifiable(prerequisites);

  @override
  bool operator ==(Object other) => other is SkillNode && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'SkillNode($id)';
}
