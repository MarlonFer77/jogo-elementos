/// Something a [SkillNode] can grant when unlocked — a [Mutation], a
/// [CombinationModifier], or a future grant kind. `SkillNode`/`SkillTree`
/// never inspect which kind it is; only `SkillProgress` filters by type
/// when collecting `grantedMutations`/`grantedCombinationModifiers`.
abstract interface class SkillGrant {
  String get id;
}
