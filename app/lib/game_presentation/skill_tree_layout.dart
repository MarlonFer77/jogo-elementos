import '../game_domain/skill_tree_catalog.dart';

/// Ordena os nós de uma branch em ordem topológica (pré-requisitos antes
/// de quem depende deles) — pra empilhar verticalmente numa coluna.
/// Assume que a branch é uma cadeia linear (cada nó com no máximo 1
/// pré-requisito dentro da mesma branch); se não for, ainda devolve uma
/// ordem válida (todo pré-requisito aparece antes de quem depende dele),
/// só não representa ramificação nenhuma visualmente — ver
/// docs/superpowers/specs/2026-09-10-skill-tree-screen-design.md.
List<SkillTreeNodeOption> orderBranchNodes(List<SkillTreeNodeOption> branchNodes) {
  final idsInBranch = branchNodes.map((n) => n.id).toSet();
  final placed = <String>{};
  final ordered = <SkillTreeNodeOption>[];
  final remaining = List<SkillTreeNodeOption>.of(branchNodes);

  while (remaining.isNotEmpty) {
    final next = remaining.firstWhere(
      (n) => n.prerequisites.where(idsInBranch.contains).every(placed.contains),
    );
    ordered.add(next);
    placed.add(next.id);
    remaining.remove(next);
  }
  return ordered;
}

/// Estado visual de um nó da Skill Tree.
enum SkillTreeNodeState { locked, available, unlocked }

/// Calcula o estado de [node] dado o que já foi desbloqueado —
/// independente de quem tem a vez (isso é decidido em outro lugar, na
/// hora de habilitar o botão de desbloquear).
SkillTreeNodeState skillTreeNodeState(SkillTreeNodeOption node, List<String> unlockedNodeIds) {
  if (unlockedNodeIds.contains(node.id)) return SkillTreeNodeState.unlocked;
  return node.prerequisites.every(unlockedNodeIds.contains)
      ? SkillTreeNodeState.available
      : SkillTreeNodeState.locked;
}
