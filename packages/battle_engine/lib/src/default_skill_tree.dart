import 'combination_modifiers.dart';
import 'element_unlocks.dart';
import 'elements.dart';
import 'max_hp_bonuses.dart';
import 'mutations.dart';
import 'skill_node.dart';
import 'skill_tree.dart';

/// Example skill tree with five independent branches, granting the
/// built-in [Mutations], [CombinationModifiers] and [MaxHpBonuses], plus
/// a sixth "elementos" branch (Bloco 2b — ver DECISION-047) granting
/// [ElementUnlocks]: one leaf per built-in element, no prerequisites
/// among them — a player picks freely which to unlock next.
/// `TrainingMatch` enforces its own turns-played gate on top of this (see
/// `element_unlock.dart`'s doc comment); `SkillTree`/`SkillProgress`
/// themselves stay unaware of that gate, only prerequisites.
/// Demonstrates that the tree structure supports different paths — a real
/// content tree is expected to grow well beyond this.
final defaultSkillTree = SkillTree([
  SkillNode(
    id: 'ember_mastery',
    name: 'Maestria da Brasa',
    description: 'Desbloqueia Combustão: habilidades passam a poder aplicar '
        'queimadura.',
    branch: 'fogo',
    grants: Mutations.combustion,
  ),
  SkillNode(
    id: 'wildfire_path',
    name: 'Caminho do Incêndio',
    description: 'Desbloqueia Incêndio: habilidades passam a poder criar '
        'uma área de fogo no campo.',
    branch: 'fogo',
    prerequisites: ['ember_mastery'],
    grants: Mutations.wildfire,
  ),
  SkillNode(
    id: 'unstable_core_training',
    name: 'Treino do Núcleo Instável',
    description: 'Desbloqueia Núcleo Instável: habilidades passam a poder '
        'ganhar chance de crítico.',
    branch: 'precisao',
    grants: Mutations.unstableCore,
  ),
  SkillNode(
    id: 'fragment_strikes',
    name: 'Golpes Fragmentados',
    description: 'Desbloqueia Fragmentação: habilidades passam a poder '
        'dividir o ataque.',
    branch: 'precisao',
    prerequisites: ['unstable_core_training'],
    grants: Mutations.fragmentation,
  ),
  SkillNode(
    id: 'elemental_insight',
    name: 'Percepção Elemental',
    description: 'Desbloqueia Propagação: combinações resultam em efeitos '
        'de campo com maior área.',
    branch: 'elemental',
    grants: CombinationModifiers.propagation,
  ),
  SkillNode(
    id: 'elemental_mastery',
    name: 'Maestria Elemental',
    description: 'Desbloqueia Instabilidade: combinações resultam em '
        'efeitos de campo com menor duração.',
    branch: 'elemental',
    prerequisites: ['elemental_insight'],
    grants: CombinationModifiers.volatility,
  ),
  SkillNode(
    id: 'vitality_training',
    name: 'Treino de Vitalidade',
    description: 'Desbloqueia Vitalidade: aumenta o HP máximo em 20.',
    branch: 'vitalidade',
    grants: MaxHpBonuses.vitality,
  ),
  SkillNode(
    id: 'guard_training',
    name: 'Treino de Guarda',
    description: 'Desbloqueia Guarda: habilidades passam a poder erguer um '
        'escudo protetor.',
    branch: 'defesa',
    grants: Mutations.guard,
  ),
  for (final unlock in ElementUnlocks.all)
    SkillNode(
      id: unlock.id,
      name: Elements.all.firstWhere((e) => e.id == unlock.elementId).name,
      description: 'Desbloqueia o elemento '
          '${Elements.all.firstWhere((e) => e.id == unlock.elementId).name} '
          'pra jogar.',
      branch: 'elementos',
      grants: unlock,
    ),
]);
