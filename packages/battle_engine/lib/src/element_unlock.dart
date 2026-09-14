import 'skill_grant.dart';

/// A [SkillGrant] that unlocks a specific element for use — the
/// build-level counterpart to [Mutation]/[CombinationModifier]/
/// [MaxHpBonus]. Plain data; [SkillProgress.grantedElementIds] collects
/// which elements a player can currently play with. `SkillTree`/
/// `SkillProgress` themselves stay unaware of any turns-played gate —
/// that's enforced one layer up, by `TrainingMatch` (see Bloco 2b,
/// DECISION-047), since it needs persisted, cross-match state this
/// engine has no concept of.
class ElementUnlock implements SkillGrant {
  @override
  final String id;
  final String elementId;

  const ElementUnlock({required this.id, required this.elementId});

  @override
  bool operator ==(Object other) => other is ElementUnlock && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'ElementUnlock($id)';
}
