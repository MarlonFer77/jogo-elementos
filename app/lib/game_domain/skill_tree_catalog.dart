import 'package:battle_engine/battle_engine.dart';

/// Game Domain's own value type for a skill node — same reasoning as
/// `ElementOption` (ver DECISION-017): UI never names a `battle_engine`
/// type, not even implicitly.
class SkillNodeOption {
  final String id;
  final String name;
  final String description;
  final String branch;

  const SkillNodeOption({
    required this.id,
    required this.name,
    required this.description,
    required this.branch,
  });
}

SkillNodeOption skillNodeOptionFrom(SkillNode node) {
  return SkillNodeOption(
    id: node.id,
    name: node.name,
    description: node.description,
    branch: node.branch,
  );
}

/// Nodes currently unlockable given [unlockedNodeIds] (prerequisites met,
/// not yet unlocked), with display info. Used by the Multiplayer UI to
/// show what a player can unlock next — the backend only ever sends node
/// ids (see DECISION-025), this maps them against the same
/// `defaultSkillTree` the backend mirrors, exactly like
/// `CombinationCatalog` already does for combination ids.
List<SkillNodeOption> availableSkillNodeOptions(List<String> unlockedNodeIds) {
  final progress = SkillProgress(defaultSkillTree, unlockedNodeIds: unlockedNodeIds);
  return progress.availableNodes.map(skillNodeOptionFrom).toList();
}
