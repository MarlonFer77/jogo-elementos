/// Immutable comparison only: never grants or persists rewards.
class BattleProgress {
  BattleProgress({
    Iterable<String> discoveries = const [],
    Iterable<String> attacks = const [],
    Iterable<String> skills = const [],
  }) : discoveries = Set.unmodifiable(discoveries),
       attacks = Set.unmodifiable(attacks),
       skills = Set.unmodifiable(skills);

  final Set<String> discoveries, attacks, skills;

  /// Null means the initial snapshot is unavailable, not zero gains.
  BattleProgress? gainedSince(BattleProgress? initial) => initial == null
      ? null
      : BattleProgress(
          discoveries: discoveries.difference(initial.discoveries),
          attacks: attacks.difference(initial.attacks),
          skills: skills.difference(initial.skills),
        );
}
