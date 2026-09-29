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
  'precisao' => 'Precisão • acumular AP e romper defesas',
  'elemental' => 'Sinergia • duração ou impacto dos combos',
  'vitalidade' => 'Resistência • mais tempo para preparar combos',
  'defesa' => 'Proteção • absorver golpes enquanto recupera AP',
  'elementos' => 'Descoberta • novas receitas e possibilidades',
  _ => '',
};

String? skillTreeNodeCaveat(String id) => switch (id) {
  'unstable_core_training' || 'fragment_strikes' =>
    'Só combos ativam. A prévia inclui concentração, fragmentação e defesas.',
  'wildfire_path' =>
    'Mais duração, não mais dano por ação. Purificação remove a Queimadura.',
  _ => null,
};

/// Nome de exibição de uma branch (ex: `'precisao'` -> `'Precisão'`) —
/// cai pra devolver a própria string se a branch não estiver no mapa
/// (nunca deveria acontecer com `defaultSkillTree` hoje, mas evita
/// quebrar silenciosamente se uma branch nova for adicionada sem
/// atualizar este mapa).
String skillTreeBranchDisplayName(String branch) =>
    _skillTreeBranchDisplayNames[branch] ?? branch;

/// Tactical guidance, not additional rules or free bonuses.
String skillTreeTactic(String id) => switch (id) {
  'ember_mastery' =>
    'Favorece pressão contínua. Combine com proteção para sobreviver enquanto a Queimadura age.',
  'wildfire_path' =>
    'Invista se as lutas duram várias ações. Purificação é uma resposta do adversário.',
  'unstable_core_training' =>
    'Prepare AP com básicos antes do combo. Mire o centro do selo para aproveitar melhor o dano.',
  'fragment_strikes' =>
    'Útil contra Escudo e Defesa; contra alvos desprotegidos, você abre mão de parte do dano.',
  'elemental_insight' =>
    'Procure combos de Queimadura ou Veneno no Livro. O benefício depende desses efeitos.',
  'elemental_mastery' =>
    'Troca desgaste prolongado por impacto imediato. Avalie se o alvo precisa cair agora.',
  'vitality_training' =>
    'Mais margem para acumular AP e conjurar triplas. Não substitui administrar a defesa.',
  'guard_training' =>
    'Favorece alternar combos e preparação. Golpes fragmentados podem atravessar parte da proteção.',
  _ =>
    'Amplia suas receitas possíveis. Depois de desbloquear, escolha quais elementos levar entre os 4 espaços da batalha.',
};

String skillBuildIdentity(Iterable<String> unlockedIds) {
  final unlocked = unlockedIds.toSet();
  final counts = <String, int>{};
  for (final node in allSkillTreeNodes()) {
    if (node.branch != 'elementos' && unlocked.contains(node.id)) {
      counts.update(node.branch, (count) => count + 1, ifAbsent: () => 1);
    }
  }
  if (counts.isEmpty) return 'Explorador · escolha seu estilo';
  final max = counts.values.reduce((a, b) => a > b ? a : b);
  final leaders = counts.entries
      .where((e) => e.value == max)
      .map((e) => skillTreeBranchDisplayName(e.key))
      .toList();
  return leaders.length > 2
      ? 'Build versátil · caminhos combinados'
      : 'Estilo: ${leaders.join(' + ')}';
}
