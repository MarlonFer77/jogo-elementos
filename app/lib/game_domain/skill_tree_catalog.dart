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
  final progress = SkillProgress(
    defaultSkillTree,
    unlockedNodeIds: unlockedNodeIds,
  );
  return progress.availableNodes.map(skillNodeOptionFrom).toList();
}

/// Um nó da Skill Tree com tudo que a árvore visual precisa pra desenhar
/// (Bloco 7) — inclui `prerequisites` e um `icon` (emoji), diferente de
/// [SkillNodeOption] que só carrega o necessário pra listar "disponíveis
/// agora".
class SkillTreeNodeOption {
  final String id;
  final String name;
  final String description;
  final String branch;
  final List<String> prerequisites;
  final String icon;

  const SkillTreeNodeOption({
    required this.id,
    required this.name,
    required this.description,
    required this.branch,
    required this.prerequisites,
    required this.icon,
  });
}

const _skillTreeNodeIcons = {
  'ember_mastery': '🔥',
  'wildfire_path': '🌋',
  'unstable_core_training': '🎯',
  'fragment_strikes': '💥',
  'elemental_insight': '🌊',
  'elemental_mastery': '⚡',
  'vitality_training': '❤️',
  'guard_training': '🛡️',
  'unlock_fire': '🔥',
  'unlock_water': '💧',
  'unlock_wind': '🌪️',
  'unlock_ice': '❄️',
  'unlock_nature': '🌱',
  'unlock_lightning': '⚡',
  'unlock_earth': '🪨',
  'unlock_shadow': '🌑',
  'unlock_light': '✨',
  'unlock_poison': '☠️',
};

/// Todos os nós de `defaultSkillTree`, com ícone — base pra tela de
/// Skill Tree visual (Bloco 7), que precisa mostrar travados/disponíveis/
/// desbloqueados juntos, não só os disponíveis agora.
List<SkillTreeNodeOption> allSkillTreeNodes() {
  return defaultSkillTree.nodes
      .map(
        (node) => SkillTreeNodeOption(
          id: node.id,
          name: node.name,
          description: node.description,
          branch: node.branch,
          prerequisites: node.prerequisites,
          icon: _skillTreeNodeIcons[node.id] ?? '❔',
        ),
      )
      .toList();
}

const _skillTreeBranchDisplayNames = {
  'fogo': 'Fogo',
  'precisao': 'Precisão',
  'elemental': 'Elemental',
  'vitalidade': 'Vitalidade',
  'defesa': 'Defesa',
  'elementos': 'Elementos',
};

String skillTreeBranchIdentity(String branch) => switch (branch) {
  'fogo' => 'Pressão • desgaste por Queimadura',
  'precisao' => 'Precisão • crítico e multigolpe ainda em desenvolvimento',
  'elemental' => 'Sinergia • duração ou impacto dos combos',
  'vitalidade' => 'Resistência • mais tempo para preparar combos',
  'defesa' => 'Proteção • absorver golpes enquanto recupera AP',
  'elementos' => 'Descoberta • novas receitas e possibilidades',
  _ => '',
};

String? skillTreeNodeCaveat(String id) => switch (id) {
  'unstable_core_training' || 'fragment_strikes' =>
    'Em desenvolvimento: este desbloqueio é salvo, mas ainda não modifica o dano da batalha.',
  'wildfire_path' => 'O campo criado ainda não causa dano contínuo próprio.',
  _ => null,
};

/// Nome de exibição de uma branch (ex: `'precisao'` -> `'Precisão'`) —
/// cai pra devolver a própria string se a branch não estiver no mapa
/// (nunca deveria acontecer com `defaultSkillTree` hoje, mas evita
/// quebrar silenciosamente se uma branch nova for adicionada sem
/// atualizar este mapa).
String skillTreeBranchDisplayName(String branch) =>
    _skillTreeBranchDisplayNames[branch] ?? branch;
