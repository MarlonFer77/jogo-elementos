import 'ability.dart';
import 'combination_modifier.dart';
import 'skill_progress.dart';

/// A player's build: their [SkillProgress], the concrete [Ability]s they've
/// composed from the mutations it grants, and the [combinationModifiers]
/// that change how any combination they trigger resolves (see
/// [TurnEngine.playTurn]). Doesn't depend on any battle — builds are created
/// and edited offline.
///
/// Validated at construction (and on every change): every mutation attached
/// to every ability, and every combination modifier, must be one
/// [skillProgress] has actually unlocked; ability ids must be unique.
class Build {
  final String id;
  final String name;
  final SkillProgress skillProgress;
  final List<Ability> abilities;
  final List<CombinationModifier> combinationModifiers;

  Build({
    required this.id,
    required this.name,
    required this.skillProgress,
    required Iterable<Ability> abilities,
    Iterable<CombinationModifier> combinationModifiers = const [],
  })  : abilities = List.unmodifiable(abilities),
        combinationModifiers = List.unmodifiable(combinationModifiers) {
    if (this.abilities.isEmpty) {
      throw ArgumentError.value(
        abilities,
        'abilities',
        'a build needs at least one ability',
      );
    }

    final seenAbilityIds = <String>{};
    for (final ability in this.abilities) {
      if (!seenAbilityIds.add(ability.id)) {
        throw ArgumentError.value(
          abilities,
          'abilities',
          'duplicate ability id "${ability.id}"',
        );
      }
    }

    final unlockedMutationIds = skillProgress.grantedMutations
        .map((mutation) => mutation.id)
        .toSet();
    for (final ability in this.abilities) {
      for (final mutation in ability.mutations) {
        if (!unlockedMutationIds.contains(mutation.id)) {
          throw ArgumentError.value(
            abilities,
            'abilities',
            '"${ability.id}" uses mutation "${mutation.id}", which is not '
                'unlocked in skillProgress',
          );
        }
      }
    }

    final unlockedModifierIds = skillProgress.grantedCombinationModifiers
        .map((modifier) => modifier.id)
        .toSet();
    for (final modifier in this.combinationModifiers) {
      if (!unlockedModifierIds.contains(modifier.id)) {
        throw ArgumentError.value(
          combinationModifiers,
          'combinationModifiers',
          '"${modifier.id}" is not unlocked in skillProgress',
        );
      }
    }
  }

  Ability? abilityById(String abilityId) {
    for (final ability in abilities) {
      if (ability.id == abilityId) return ability;
    }
    return null;
  }

  /// Returns a new build with [ability] added, or replacing the existing
  /// ability with the same id. Re-validates against [skillProgress].
  Build withAbility(Ability ability) {
    final updated = [
      for (final existing in abilities)
        if (existing.id != ability.id) existing,
      ability,
    ];
    return Build(
      id: id,
      name: name,
      skillProgress: skillProgress,
      abilities: updated,
      combinationModifiers: combinationModifiers,
    );
  }

  /// Returns a new build with [modifier] added, or replacing the existing
  /// one with the same id. Re-validates against [skillProgress].
  Build withCombinationModifier(CombinationModifier modifier) {
    final updated = [
      for (final existing in combinationModifiers)
        if (existing.id != modifier.id) existing,
      modifier,
    ];
    return Build(
      id: id,
      name: name,
      skillProgress: skillProgress,
      abilities: abilities,
      combinationModifiers: updated,
    );
  }

  /// Returns a new build under [newProgress]. Re-validates: abilities or
  /// combination modifiers no longer unlocked under [newProgress] make this
  /// throw.
  Build withSkillProgress(SkillProgress newProgress) {
    return Build(
      id: id,
      name: name,
      skillProgress: newProgress,
      abilities: abilities,
      combinationModifiers: combinationModifiers,
    );
  }
}
