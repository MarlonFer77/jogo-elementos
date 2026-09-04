import 'ability_effect.dart';
import 'skill_grant.dart';

/// A modifier that can be attached to an [Ability], changing how it
/// resolves — e.g. applying a status, adding a field effect, adjusting hit
/// count or crit chance. New mutations are added as new [Mutation]
/// instances; [AbilityEngine] never branches on which mutation it is.
class Mutation implements SkillGrant {
  @override
  final String id;
  final String name;
  final String description;
  final AbilityEffect Function(AbilityEffect effect) apply;

  Mutation({
    required this.id,
    required this.name,
    required this.description,
    required this.apply,
  });

  @override
  bool operator ==(Object other) => other is Mutation && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Mutation($id)';
}
