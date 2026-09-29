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
    description:
        'Combos aplicam Queimadura: 3 de dano por 2 ações. Básicos não ativam; Escudo bloqueia. Não acumula com queimadura mais forte.',
    branch: 'fogo',
    grants: Mutations.combustion,
  ),
  SkillNode(
    id: 'wildfire_path',
    name: 'Caminho do Incêndio',
    description:
        'Incêndio: a Queimadura passiva dura 3 ações em vez de 2. Não acumula dano por ação; Escudo bloqueia.',
    branch: 'fogo',
    prerequisites: ['ember_mastery'],
    grants: Mutations.wildfire,
  ),
  SkillNode(
    id: 'unstable_core_training',
    name: 'Treino do Núcleo Instável',
    description:
        'Concentração: combos com AP cheio ao conjurar causam +25% de dano direto. Inclui regeneração; sem sorte.',
    branch: 'precisao',
    grants: Mutations.unstableCore,
  ),
  SkillNode(
    id: 'fragment_strikes',
    name: 'Golpes Fragmentados',
    description:
        'Fragmentação: 80% do dano em 2 golpes. Escudo/Defesa protegem só do primeiro. Status, cura e AP não duplicam; Escudo ainda barra status.',
    branch: 'precisao',
    prerequisites: ['unstable_core_training'],
    grants: Mutations.fragmentation,
  ),
  SkillNode(
    id: 'elemental_insight',
    name: 'Percepção Elemental',
    description:
        'Propagação: Queimadura e Veneno dos combos causam +1 por tick. Favorece pressão contínua; não altera as passivas.',
    branch: 'elemental',
    grants: CombinationModifiers.propagation,
  ),
  SkillNode(
    id: 'elemental_mastery',
    name: 'Maestria Elemental',
    description:
        'Instabilidade: combos com dano contínuo de 2+ ações causam +4 de dano direto, mas cada efeito contínuo perde 1 ação (mínimo 1). Troque duração por impacto.',
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
    description:
        'Conjurar um combo ergue Escudo por 2 ações: bloqueia o próximo golpe. Básicos não ativam.',
    branch: 'defesa',
    grants: Mutations.guard,
  ),
  for (final unlock in ElementUnlocks.all)
    SkillNode(
      id: unlock.id,
      name: Elements.all.firstWhere((e) => e.id == unlock.elementId).name,
      description:
          'Desbloqueia o elemento '
          '${Elements.all.firstWhere((e) => e.id == unlock.elementId).name} '
          'pra jogar.',
      branch: 'elementos',
      grants: unlock,
    ),
]);
