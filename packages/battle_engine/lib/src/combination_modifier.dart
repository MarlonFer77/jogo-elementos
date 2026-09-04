import 'field_effect.dart';
import 'skill_grant.dart';

/// A modifier a build can carry that changes how a resolved combination's
/// [FieldEffect] turns out — bigger area, shorter duration, etc. The
/// build-level counterpart to [Mutation] (which changes an ability's own
/// effect instead). Applied by [TurnEngine.playTurn] before the field
/// effect is added to the [BattleState]; new modifiers are new instances,
/// the engine never branches on which one it is.
class CombinationModifier implements SkillGrant {
  @override
  final String id;
  final String name;
  final String description;
  final FieldEffect Function(FieldEffect effect) apply;

  CombinationModifier({
    required this.id,
    required this.name,
    required this.description,
    required this.apply,
  });

  @override
  bool operator ==(Object other) =>
      other is CombinationModifier && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'CombinationModifier($id)';
}
