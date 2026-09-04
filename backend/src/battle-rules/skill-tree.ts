import { combinationModifiersById, type CombinationModifier } from "./combination-modifiers.js";
import { mutationsById, type Mutation } from "./mutations.js";

type SkillGrantRef =
  | { readonly kind: "mutation"; readonly id: string }
  | { readonly kind: "combinationModifier"; readonly id: string }
  | { readonly kind: "maxHpBonus"; readonly id: string };

export interface SkillTreeNodeDef {
  readonly id: string;
  readonly prerequisites: readonly string[];
  readonly grant: SkillGrantRef;
}

/**
 * Mirrors defaultSkillTree in default_skill_tree.dart — ids, prerequisites
 * and what each node grants, kept manually in sync (same pattern as
 * default_combinations.dart/combination-book.ts — see DECISION-013/014).
 * No name/description/branch: the client already has that from its own
 * `battle_engine` (it renders the actual Skill Tree already, for Modo
 * Treino) — see ARCHITECTURE.md.
 *
 * Unlike `SkillNode`/`SkillTree`/`SkillProgress` in Dart (a generic graph
 * + a class tracking unlock state), this is plain data plus pure functions
 * over a caller-supplied `unlockedNodeIds: string[]` — MatchStore is what
 * actually holds that list per player, the same way it holds `hp`. No
 * cycle-detection here either: this tree is trusted static data, already
 * validated by battle_engine's own test suite, not a value normal callers
 * of a backend deployment would ever construct at runtime.
 */
export const defaultSkillTreeNodes: readonly SkillTreeNodeDef[] = [
  { id: "ember_mastery", prerequisites: [], grant: { kind: "mutation", id: "combustion" } },
  { id: "wildfire_path", prerequisites: ["ember_mastery"], grant: { kind: "mutation", id: "wildfire" } },
  { id: "unstable_core_training", prerequisites: [], grant: { kind: "mutation", id: "unstable_core" } },
  {
    id: "fragment_strikes",
    prerequisites: ["unstable_core_training"],
    grant: { kind: "mutation", id: "fragmentation" },
  },
  { id: "elemental_insight", prerequisites: [], grant: { kind: "combinationModifier", id: "propagation" } },
  {
    id: "elemental_mastery",
    prerequisites: ["elemental_insight"],
    grant: { kind: "combinationModifier", id: "volatility" },
  },
  { id: "vitality_training", prerequisites: [], grant: { kind: "maxHpBonus", id: "vitality" } },
  { id: "guard_training", prerequisites: [], grant: { kind: "mutation", id: "guard" } },
];

export function nodeById(nodeId: string): SkillTreeNodeDef | undefined {
  return defaultSkillTreeNodes.find((node) => node.id === nodeId);
}

/** Whether `nodeId` exists, isn't unlocked yet, and has every prerequisite
 * already unlocked — mirrors SkillProgress.canUnlock. */
export function canUnlock(unlockedNodeIds: readonly string[], nodeId: string): boolean {
  const node = nodeById(nodeId);
  if (!node || unlockedNodeIds.includes(nodeId)) return false;
  return node.prerequisites.every((id) => unlockedNodeIds.includes(id));
}

/** Nodes currently unlockable: prerequisites met, not yet unlocked —
 * mirrors SkillProgress.availableNodes (ids only, see the module doc). */
export function availableNodeIds(unlockedNodeIds: readonly string[]): readonly string[] {
  return defaultSkillTreeNodes
    .filter((node) => !unlockedNodeIds.includes(node.id))
    .filter((node) => node.prerequisites.every((id) => unlockedNodeIds.includes(id)))
    .map((node) => node.id);
}

/** Mutations granted by unlocked nodes, in unlock order, deduplicated by
 * id — mirrors SkillProgress.grantedMutations. */
export function grantedMutations(unlockedNodeIds: readonly string[]): readonly Mutation[] {
  const seen = new Set<string>();
  const result: Mutation[] = [];
  for (const nodeId of unlockedNodeIds) {
    const node = nodeById(nodeId);
    if (node?.grant.kind === "mutation" && !seen.has(node.grant.id)) {
      seen.add(node.grant.id);
      result.push(mutationsById[node.grant.id]!);
    }
  }
  return result;
}

/** Combination modifiers granted by unlocked nodes, in unlock order,
 * deduplicated by id — mirrors SkillProgress.grantedCombinationModifiers. */
export function grantedCombinationModifiers(
  unlockedNodeIds: readonly string[],
): readonly CombinationModifier[] {
  const seen = new Set<string>();
  const result: CombinationModifier[] = [];
  for (const nodeId of unlockedNodeIds) {
    const node = nodeById(nodeId);
    if (node?.grant.kind === "combinationModifier" && !seen.has(node.grant.id)) {
      seen.add(node.grant.id);
      result.push(combinationModifiersById[node.grant.id]!);
    }
  }
  return result;
}
