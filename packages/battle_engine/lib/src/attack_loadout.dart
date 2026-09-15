/// Tracks which [ElementCombination]s a single player has unlocked as a
/// personal "attack" (triggered at least once), and which ≤3 of those
/// are currently equipped — the only ones that player can trigger again
/// (Bloco 2c, DECISION-048). Immutable — [withUnlocked]/[withEquipped]
/// return a new instance. Independent from [DiscoveryBook] (shared,
/// meta-progression-only, unaffected by this class) — see
/// docs/superpowers/specs/2026-09-15-equippable-attacks-design.md for
/// why they're kept separate.
class AttackLoadout {
  final Set<String> unlockedCombinationIds;
  final List<String> equippedCombinationIds;

  AttackLoadout({
    Set<String> unlockedCombinationIds = const {},
    List<String> equippedCombinationIds = const [],
  })  : unlockedCombinationIds = Set.unmodifiable(unlockedCombinationIds),
        equippedCombinationIds = List.unmodifiable(equippedCombinationIds);

  bool isUnlocked(String combinationId) =>
      unlockedCombinationIds.contains(combinationId);

  bool isEquipped(String combinationId) =>
      equippedCombinationIds.contains(combinationId);

  /// Returns a new loadout with [combinationId] marked as unlocked. If
  /// already unlocked, returns this same instance (no-op). If there's
  /// room (fewer than 3 equipped), also equips it automatically.
  AttackLoadout withUnlocked(String combinationId) {
    if (isUnlocked(combinationId)) return this;
    final nextEquipped = equippedCombinationIds.length < 3
        ? [...equippedCombinationIds, combinationId]
        : equippedCombinationIds;
    return AttackLoadout(
      unlockedCombinationIds: {...unlockedCombinationIds, combinationId},
      equippedCombinationIds: nextEquipped,
    );
  }

  /// Returns a new loadout with the equipped set replaced by
  /// [combinationIds]. Throws `ArgumentError` if it has more than 3
  /// ids, or if any id isn't already unlocked.
  AttackLoadout withEquipped(List<String> combinationIds) {
    if (combinationIds.length > 3) {
      throw ArgumentError.value(
        combinationIds,
        'combinationIds',
        'cannot equip more than 3 attacks',
      );
    }
    for (final id in combinationIds) {
      if (!isUnlocked(id)) {
        throw ArgumentError.value(
          id,
          'combinationIds',
          'not unlocked yet, cannot be equipped',
        );
      }
    }
    return AttackLoadout(
      unlockedCombinationIds: unlockedCombinationIds,
      equippedCombinationIds: combinationIds,
    );
  }
}
