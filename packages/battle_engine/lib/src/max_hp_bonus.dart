import 'skill_grant.dart';

/// A modifier a Skill Tree node can grant that raises a combatant's max
/// HP. The build-level counterpart to [Mutation]/[CombinationModifier], but
/// plain data (no function to apply) — [BattleState.withMaxHpIncreased]
/// does the actual work, driven by whoever is orchestrating the match
/// (e.g. `TrainingMatch`).
class MaxHpBonus implements SkillGrant {
  @override
  final String id;
  final String name;
  final String description;
  final int bonus;

  const MaxHpBonus({
    required this.id,
    required this.name,
    required this.description,
    required this.bonus,
  });

  @override
  bool operator ==(Object other) => other is MaxHpBonus && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'MaxHpBonus($id)';
}
