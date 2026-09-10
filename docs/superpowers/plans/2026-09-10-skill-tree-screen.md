# Tela de Skill Tree visual (Bloco 7) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Substituir o modal de "disponíveis agora" por uma tela cheia com a Skill Tree inteira — 5 branches lado a lado (roláveis), nós travados/disponíveis/desbloqueados visíveis juntos, com ícone e linha conectora — compartilhada por Treino e Multiplayer.

**Architecture:** Funções puras (`orderBranchNodes`, `skillTreeNodeState`) calculam ordem e estado sem depender de Flutter. Um `SkillTreeNodeWidget` (círculo + estado) e uma `SkillTreeScreen` (uma coluna por branch, painel de detalhe ao tocar um nó) compõem a tela, alimentada por um `onUnlock` genérico (`Future<String? > Function(String nodeId)`) que cada chamador (Treino/Multiplayer) implementa com sua própria lógica de erro.

**Tech Stack:** Flutter + Dart, mesmos componentes pixel art já existentes (`PixelOutlinedText`, `PixelMenuButton`, `PixelSheetPanel`, `PixelContentPanel`, `ArenaBackdropPainter`, `pixelSlideRoute`).

**Spec:** [docs/superpowers/specs/2026-09-10-skill-tree-screen-design.md](../specs/2026-09-10-skill-tree-screen-design.md)

## Global Constraints

- Nenhuma mudança em `battle_engine`/backend — `defaultSkillTree`/`SkillNode`/`SkillTree`/`SkillProgress` continuam exatamente os mesmos. Tudo novo (ícone, nome de branch) vive só em `game_domain`.
- Layout assume cadeia linear por branch (ver spec) — `orderBranchNodes` ainda produz uma ordem topológica válida se isso não for verdade, só não desenha ramificação.
- `available` (estado do nó) nunca considera de quem é a vez — só se os pré-requisitos foram cumpridos. "De quem é a vez" só entra na hora de habilitar o botão "Desbloquear" no painel de detalhe (`canUnlockNow`).
- Paleta já estabelecida: `Color(0xFF2B2B2B)` (borda/texto escuro), `Color(0xFFF4F4E4)` (creme, não-selecionado/disponível/travado), `Color(0xFFF4C94A)` (dourado, desbloqueado). Nó travado usa `Opacity(0.4)`, mesmo padrão de botão desabilitado.
- Nenhum texto visível novo além de: nomes/descrições dos nós já existentes, `'Requer: ...'`, `'Só dá pra desbloquear na sua vez.'` (copy já usada hoje, reaproveitada).
- Lição do Bloco 3, ainda válida: `flutter run -d web-server` **não** recompila em reload de página — só um `preview_stop`+`preview_start` novo pega mudanças de código Dart.
- Lição do bloco anterior (checagem de atualização): em teste de widget, `tester.pump()` **sem duração** pode não avançar o relógio falso o suficiente pra resolver certas esperas assíncronas — prefira `tester.pump(const Duration(milliseconds: N))` sempre que uma ação dependa de um `Future` resolver, seguindo o padrão de 400ms já usado nesta suíte pra animações de transição/modal.
- `multiplayer_battle_screen.dart` importa hoje `'../game_domain/skill_tree_catalog.dart'` só por causa de `SkillNodeOption`/`availableSkillNodeOptions`, usados dentro do `_openSkillTree` atual que este bloco substitui por completo — **remover esse import** explicitamente na Task 8 (senão o lint `unused_import` do `flutter_lints` quebra `flutter analyze`).
- Cada task termina com `flutter analyze` limpo e `flutter test` verde antes do commit.

---

## Task 1: Dados novos em `skill_tree_catalog.dart`

**Files:**
- Modify: `app/lib/game_domain/skill_tree_catalog.dart` (arquivo existente, só adiciona ao final)
- Modify: `app/test/game_domain/skill_tree_catalog_test.dart` (arquivo existente, só adiciona ao final)

**Interfaces:**
- Consumes: nada de outras tasks.
- Produces: `class SkillTreeNodeOption { id, name, description, branch, prerequisites, icon }`, `List<SkillTreeNodeOption> allSkillTreeNodes()`, `String skillTreeBranchDisplayName(String branch)` — usados pelas Tasks 3, 4, 5.

- [ ] **Step 1: Write the failing test**

Adicionar ao final de `app/test/game_domain/skill_tree_catalog_test.dart` (dentro do `main()`, depois dos testes existentes de `availableSkillNodeOptions`):

```dart
  group('allSkillTreeNodes', () {
    test('returns all 8 nodes from defaultSkillTree with icons and prerequisites', () {
      final nodes = allSkillTreeNodes();

      expect(nodes, hasLength(8));

      final ember = nodes.firstWhere((n) => n.id == 'ember_mastery');
      expect(ember.name, 'Maestria da Brasa');
      expect(ember.branch, 'fogo');
      expect(ember.icon, '🔥');
      expect(ember.prerequisites, isEmpty);

      final wildfire = nodes.firstWhere((n) => n.id == 'wildfire_path');
      expect(wildfire.prerequisites, ['ember_mastery']);
      expect(wildfire.icon, '🌋');
    });
  });

  group('skillTreeBranchDisplayName', () {
    test('returns the known display names', () {
      expect(skillTreeBranchDisplayName('fogo'), 'Fogo');
      expect(skillTreeBranchDisplayName('precisao'), 'Precisão');
      expect(skillTreeBranchDisplayName('elemental'), 'Elemental');
      expect(skillTreeBranchDisplayName('vitalidade'), 'Vitalidade');
      expect(skillTreeBranchDisplayName('defesa'), 'Defesa');
    });

    test('falls back to the raw branch string when unknown', () {
      expect(skillTreeBranchDisplayName('mystery'), 'mystery');
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/game_domain/skill_tree_catalog_test.dart`
Expected: FAIL — `allSkillTreeNodes`/`skillTreeBranchDisplayName` não existem ainda.

- [ ] **Step 3: Write minimal implementation**

Adicionar ao final de `app/lib/game_domain/skill_tree_catalog.dart` (mantendo `SkillNodeOption`/`skillNodeOptionFrom`/`availableSkillNodeOptions` existentes intactos — continuam existindo, sem uso depois deste bloco, mas removê-las não é objetivo dele):

```dart
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
};

/// Todos os nós de `defaultSkillTree`, com ícone — base pra tela de
/// Skill Tree visual (Bloco 7), que precisa mostrar travados/disponíveis/
/// desbloqueados juntos, não só os disponíveis agora.
List<SkillTreeNodeOption> allSkillTreeNodes() {
  return defaultSkillTree.nodes
      .map((node) => SkillTreeNodeOption(
            id: node.id,
            name: node.name,
            description: node.description,
            branch: node.branch,
            prerequisites: node.prerequisites,
            icon: _skillTreeNodeIcons[node.id] ?? '❔',
          ))
      .toList();
}

const _skillTreeBranchDisplayNames = {
  'fogo': 'Fogo',
  'precisao': 'Precisão',
  'elemental': 'Elemental',
  'vitalidade': 'Vitalidade',
  'defesa': 'Defesa',
};

/// Nome de exibição de uma branch (ex: `'precisao'` -> `'Precisão'`) —
/// cai pra devolver a própria string se a branch não estiver no mapa
/// (nunca deveria acontecer com `defaultSkillTree` hoje, mas evita
/// quebrar silenciosamente se uma branch nova for adicionada sem
/// atualizar este mapa).
String skillTreeBranchDisplayName(String branch) =>
    _skillTreeBranchDisplayNames[branch] ?? branch;
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/game_domain/skill_tree_catalog_test.dart`
Expected: PASS (6 testes: 3 já existentes + 3 novos).

- [ ] **Step 5: `flutter analyze`**

Run: `cd app && flutter analyze`
Expected: "No issues found!"

- [ ] **Step 6: Commit**

```bash
git add app/lib/game_domain/skill_tree_catalog.dart app/test/game_domain/skill_tree_catalog_test.dart
git commit -m "Adiciona SkillTreeNodeOption/allSkillTreeNodes/skillTreeBranchDisplayName"
```

---

## Task 2: `TrainingMatch.unlockedNodeIdsForCurrentPlayer`

**Files:**
- Modify: `app/lib/game_domain/training_match.dart:94-97` (logo após `availableSkillNodesForCurrentPlayer`)
- Modify: `app/test/game_domain/training_match_test.dart` (adiciona ao final)

**Interfaces:**
- Consumes: nada de outras tasks.
- Produces: `List<String> get unlockedNodeIdsForCurrentPlayer` em `TrainingMatch` — usado pela Task 7 (`TrainingScreen`).

- [ ] **Step 1: Write the failing test**

Adicionar ao final de `app/test/game_domain/training_match_test.dart` (dentro do `main()`):

```dart
  test('unlockedNodeIdsForCurrentPlayer reflects what the current player has unlocked', () {
    final match = TrainingMatch();

    expect(match.unlockedNodeIdsForCurrentPlayer, isEmpty);

    match.unlockSkillForCurrentPlayer('ember_mastery');

    expect(match.unlockedNodeIdsForCurrentPlayer, ['ember_mastery']);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/game_domain/training_match_test.dart`
Expected: FAIL — `unlockedNodeIdsForCurrentPlayer` não existe ainda.

- [ ] **Step 3: Write minimal implementation**

Em `app/lib/game_domain/training_match.dart`, logo depois do getter `availableSkillNodesForCurrentPlayer` (que termina em `.toList();`), adicionar:

```dart
  /// Ids dos nós que o jogador da vez atual já desbloqueou — usado pela
  /// tela de Skill Tree visual (Bloco 7) pra saber o estado de cada nó da
  /// árvore inteira, não só os disponíveis agora.
  List<String> get unlockedNodeIdsForCurrentPlayer => _currentProgress.unlockedNodeIds;
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/game_domain/training_match_test.dart`
Expected: PASS (todos os testes do arquivo, incluindo o novo).

- [ ] **Step 5: `flutter analyze`**

Run: `cd app && flutter analyze`
Expected: "No issues found!"

- [ ] **Step 6: Commit**

```bash
git add app/lib/game_domain/training_match.dart app/test/game_domain/training_match_test.dart
git commit -m "TrainingMatch ganha unlockedNodeIdsForCurrentPlayer"
```

---

## Task 3: `skill_tree_layout.dart` (ordenação + estado, puros)

**Files:**
- Create: `app/lib/game_presentation/skill_tree_layout.dart`
- Test: `app/test/game_presentation/skill_tree_layout_test.dart`

**Interfaces:**
- Consumes: `SkillTreeNodeOption` (Task 1).
- Produces: `List<SkillTreeNodeOption> orderBranchNodes(List<SkillTreeNodeOption> branchNodes)`, `enum SkillTreeNodeState { locked, available, unlocked }`, `SkillTreeNodeState skillTreeNodeState(SkillTreeNodeOption node, List<String> unlockedNodeIds)` — usados pelas Tasks 4 e 5.

- [ ] **Step 1: Write the failing test**

```dart
// app/test/game_presentation/skill_tree_layout_test.dart
import 'package:app/game_domain/skill_tree_catalog.dart';
import 'package:app/game_presentation/skill_tree_layout.dart';
import 'package:flutter_test/flutter_test.dart';

const _a = SkillTreeNodeOption(
  id: 'a',
  name: 'A',
  description: '',
  branch: 'x',
  prerequisites: [],
  icon: '🔥',
);
const _b = SkillTreeNodeOption(
  id: 'b',
  name: 'B',
  description: '',
  branch: 'x',
  prerequisites: ['a'],
  icon: '🔥',
);
const _c = SkillTreeNodeOption(
  id: 'c',
  name: 'C',
  description: '',
  branch: 'x',
  prerequisites: ['b'],
  icon: '🔥',
);

void main() {
  group('orderBranchNodes', () {
    test('returns a single node unchanged', () {
      expect(orderBranchNodes([_a]), [_a]);
    });

    test('places the prerequisite before the node that depends on it', () {
      expect(orderBranchNodes([_b, _a]), [_a, _b]);
    });

    test('orders a chain of three regardless of input order', () {
      expect(orderBranchNodes([_c, _a, _b]), [_a, _b, _c]);
    });
  });

  group('skillTreeNodeState', () {
    test('a node with no prerequisites and not unlocked is available', () {
      expect(skillTreeNodeState(_a, const []), SkillTreeNodeState.available);
    });

    test('a node whose prerequisite is not met is locked', () {
      expect(skillTreeNodeState(_b, const []), SkillTreeNodeState.locked);
    });

    test('a node whose prerequisite is met and is not unlocked is available', () {
      expect(skillTreeNodeState(_b, const ['a']), SkillTreeNodeState.available);
    });

    test('a node already in unlockedNodeIds is unlocked', () {
      expect(skillTreeNodeState(_a, const ['a']), SkillTreeNodeState.unlocked);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/game_presentation/skill_tree_layout_test.dart`
Expected: FAIL — `skill_tree_layout.dart` não existe ainda.

- [ ] **Step 3: Write minimal implementation**

```dart
// app/lib/game_presentation/skill_tree_layout.dart
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/game_presentation/skill_tree_layout_test.dart`
Expected: PASS (7 testes).

- [ ] **Step 5: `flutter analyze`**

Run: `cd app && flutter analyze`
Expected: "No issues found!"

- [ ] **Step 6: Commit**

```bash
git add app/lib/game_presentation/skill_tree_layout.dart app/test/game_presentation/skill_tree_layout_test.dart
git commit -m "Adiciona orderBranchNodes e skillTreeNodeState (layout puro)"
```

---

## Task 4: `SkillTreeNodeWidget`

**Files:**
- Create: `app/lib/game_presentation/skill_tree_node_widget.dart`
- Test: `app/test/game_presentation/skill_tree_node_widget_test.dart`

**Interfaces:**
- Consumes: `SkillTreeNodeState` (Task 3).
- Produces: `SkillTreeNodeWidget({required String name, required String icon, required SkillTreeNodeState state, required VoidCallback onTap})` — usado pela Task 5 (`SkillTreeScreen`).

- [ ] **Step 1: Write the failing test**

```dart
// app/test/game_presentation/skill_tree_node_widget_test.dart
import 'package:app/game_presentation/skill_tree_layout.dart';
import 'package:app/game_presentation/skill_tree_node_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the name and icon, and calls onTap when tapped',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SkillTreeNodeWidget(
          name: 'Maestria da Brasa',
          icon: '🔥',
          state: SkillTreeNodeState.available,
          onTap: () => tapped = true,
        ),
      ),
    ));

    expect(find.text('Maestria da Brasa'), findsOneWidget);
    expect(find.text('🔥'), findsOneWidget);

    await tester.tap(find.text('Maestria da Brasa'));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('renders without throwing for every state', (tester) async {
    for (final state in SkillTreeNodeState.values) {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SkillTreeNodeWidget(
            name: 'Nó',
            icon: '🔥',
            state: state,
            onTap: () {},
          ),
        ),
      ));
      expect(find.text('Nó'), findsOneWidget);
    }
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/game_presentation/skill_tree_node_widget_test.dart`
Expected: FAIL — `skill_tree_node_widget.dart` não existe ainda.

- [ ] **Step 3: Write minimal implementation**

```dart
// app/lib/game_presentation/skill_tree_node_widget.dart
import 'package:flutter/material.dart';

import 'skill_tree_layout.dart';

/// Um nó da árvore de habilidades — círculo com ícone, cor de acordo com
/// o estado (travado/disponível/desbloqueado). Sempre tocável: é o painel
/// de detalhe aberto por `onTap` que decide o que mostrar pra cada
/// estado — ver `SkillTreeScreen`.
class SkillTreeNodeWidget extends StatelessWidget {
  const SkillTreeNodeWidget({
    super.key,
    required this.name,
    required this.icon,
    required this.state,
    required this.onTap,
  });

  final String name;
  final String icon;
  final SkillTreeNodeState state;
  final VoidCallback onTap;

  Color get _color {
    return state == SkillTreeNodeState.unlocked
        ? const Color(0xFFF4C94A)
        : const Color(0xFFF4F4E4);
  }

  double get _opacity => state == SkillTreeNodeState.locked ? 0.4 : 1.0;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: _opacity,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _color,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF2B2B2B), width: 3),
              ),
              child: Text(icon, style: const TextStyle(fontSize: 24)),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 72,
              child: Text(
                name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  color: Color(0xFF2B2B2B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/game_presentation/skill_tree_node_widget_test.dart`
Expected: PASS (2 testes).

- [ ] **Step 5: `flutter analyze`**

Run: `cd app && flutter analyze`
Expected: "No issues found!"

- [ ] **Step 6: Commit**

```bash
git add app/lib/game_presentation/skill_tree_node_widget.dart app/test/game_presentation/skill_tree_node_widget_test.dart
git commit -m "Adiciona SkillTreeNodeWidget"
```

---

## Task 5: `SkillTreeScreen`

**Files:**
- Create: `app/lib/ui/skill_tree_screen.dart`
- Test: `app/test/skill_tree_screen_test.dart`

**Interfaces:**
- Consumes: `allSkillTreeNodes`/`skillTreeBranchDisplayName` (Task 1), `orderBranchNodes`/`SkillTreeNodeState`/`skillTreeNodeState` (Task 3), `SkillTreeNodeWidget` (Task 4), `PixelOutlinedText`/`PixelMenuButton`/`PixelSheetPanel`/`PixelContentPanel`/`ArenaBackdropPainter` (já existentes).
- Produces: `SkillTreeScreen({required String title, required List<String> unlockedNodeIds, required bool canUnlockNow, required Future<String?> Function(String nodeId) onUnlock})` — usado pelas Tasks 7 e 8.

- [ ] **Step 1: Write the failing test**

```dart
// app/test/skill_tree_screen_test.dart
import 'package:app/game_presentation/skill_tree_layout.dart';
import 'package:app/game_presentation/skill_tree_node_widget.dart';
import 'package:app/ui/skill_tree_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('tapping a locked node shows its missing prerequisites',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SkillTreeScreen(
        title: 'Habilidades',
        unlockedNodeIds: const [],
        canUnlockNow: true,
        onUnlock: (_) async => throw StateError('should not be called'),
      ),
    ));
    await tester.pump();

    await tester.tap(find.text('Caminho do Incêndio'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('Requer: Maestria da Brasa'), findsOneWidget);
    expect(find.text('Desbloquear'), findsNothing);
  });

  testWidgets(
      'tapping an available node unlocks it on success and updates the '
      'node state', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SkillTreeScreen(
        title: 'Habilidades',
        unlockedNodeIds: const [],
        canUnlockNow: true,
        onUnlock: (nodeId) async => null,
      ),
    ));
    await tester.pump();

    expect(
      tester.widget<SkillTreeNodeWidget>(
        find.widgetWithText(SkillTreeNodeWidget, 'Maestria da Brasa'),
      ).state,
      SkillTreeNodeState.available,
    );

    await tester.tap(find.text('Maestria da Brasa'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Desbloquear'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      tester.widget<SkillTreeNodeWidget>(
        find.widgetWithText(SkillTreeNodeWidget, 'Maestria da Brasa'),
      ).state,
      SkillTreeNodeState.unlocked,
    );
  });

  testWidgets(
      "an available node shows a turn notice instead of the button when "
      "it's not the player's turn", (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SkillTreeScreen(
        title: 'Habilidades',
        unlockedNodeIds: const [],
        canUnlockNow: false,
        onUnlock: (_) async => throw StateError('should not be called'),
      ),
    ));
    await tester.pump();

    await tester.tap(find.text('Maestria da Brasa'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Só dá pra desbloquear na sua vez.'), findsOneWidget);
    expect(find.text('Desbloquear'), findsNothing);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/skill_tree_screen_test.dart`
Expected: FAIL — `skill_tree_screen.dart` não existe ainda.

- [ ] **Step 3: Write minimal implementation**

```dart
// app/lib/ui/skill_tree_screen.dart
import 'package:flutter/material.dart';

import '../game_domain/skill_tree_catalog.dart';
import '../game_presentation/pixel_arena_background.dart';
import '../game_presentation/pixel_content_panel.dart';
import '../game_presentation/pixel_menu_button.dart';
import '../game_presentation/pixel_outlined_text.dart';
import '../game_presentation/pixel_sheet_panel.dart';
import '../game_presentation/skill_tree_layout.dart';
import '../game_presentation/skill_tree_node_widget.dart';

/// Tela cheia com a Skill Tree inteira — travados/disponíveis/
/// desbloqueados juntos, uma coluna por branch, roláveis
/// horizontalmente. Compartilhada por Treino e Multiplayer (Bloco 7) —
/// substitui os dois modais quase idênticos que existiam antes. Ver
/// docs/superpowers/specs/2026-09-10-skill-tree-screen-design.md.
class SkillTreeScreen extends StatefulWidget {
  const SkillTreeScreen({
    super.key,
    required this.title,
    required this.unlockedNodeIds,
    required this.canUnlockNow,
    required this.onUnlock,
  });

  final String title;
  final List<String> unlockedNodeIds;
  final bool canUnlockNow;
  final Future<String?> Function(String nodeId) onUnlock;

  @override
  State<SkillTreeScreen> createState() => _SkillTreeScreenState();
}

class _SkillTreeScreenState extends State<SkillTreeScreen> {
  late List<String> _unlockedNodeIds = List.of(widget.unlockedNodeIds);

  @override
  Widget build(BuildContext context) {
    final allNodes = allSkillTreeNodes();
    final branches = allNodes.map((n) => n.branch).toSet().toList();

    return Stack(
      children: [
        Positioned.fill(child: CustomPaint(painter: ArenaBackdropPainter())),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: PixelOutlinedText(widget.title, fontSize: 20),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: PixelContentPanel(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final branch in branches)
                      Padding(
                        padding: const EdgeInsets.only(right: 24),
                        child: _BranchColumn(
                          branch: branch,
                          nodes: orderBranchNodes(
                            allNodes.where((n) => n.branch == branch).toList(),
                          ),
                          unlockedNodeIds: _unlockedNodeIds,
                          onNodeTap: _openNodeDetail,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _openNodeDetail(SkillTreeNodeOption node) {
    final state = skillTreeNodeState(node, _unlockedNodeIds);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return PixelSheetPanel(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PixelOutlinedText(node.name, fontSize: 18),
                const SizedBox(height: 8),
                Text(node.description),
                const SizedBox(height: 12),
                if (state == SkillTreeNodeState.locked)
                  Text('Requer: ${_prerequisiteNames(node)}')
                else if (state == SkillTreeNodeState.available && !widget.canUnlockNow)
                  const Text('Só dá pra desbloquear na sua vez.')
                else if (state == SkillTreeNodeState.available)
                  PixelMenuButton(
                    label: 'Desbloquear',
                    onPressed: () async {
                      final error = await widget.onUnlock(node.id);
                      if (error != null) {
                        if (!sheetContext.mounted) return;
                        ScaffoldMessenger.of(sheetContext).showSnackBar(
                          SnackBar(content: Text(error)),
                        );
                        return;
                      }
                      setState(() => _unlockedNodeIds = [..._unlockedNodeIds, node.id]);
                      if (!sheetContext.mounted) return;
                      Navigator.of(sheetContext).pop();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _prerequisiteNames(SkillTreeNodeOption node) {
    final all = allSkillTreeNodes();
    return node.prerequisites
        .map((id) => all.firstWhere((n) => n.id == id).name)
        .join(', ');
  }
}

class _BranchColumn extends StatelessWidget {
  const _BranchColumn({
    required this.branch,
    required this.nodes,
    required this.unlockedNodeIds,
    required this.onNodeTap,
  });

  final String branch;
  final List<SkillTreeNodeOption> nodes;
  final List<String> unlockedNodeIds;
  final void Function(SkillTreeNodeOption node) onNodeTap;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Text(
            skillTreeBranchDisplayName(branch),
            style: const TextStyle(
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              color: Color(0xFF2B2B2B),
            ),
          ),
          const SizedBox(height: 12),
          for (final node in nodes) ...[
            if (node != nodes.first)
              Container(width: 3, height: 16, color: const Color(0xFF2B2B2B)),
            SkillTreeNodeWidget(
              name: node.name,
              icon: node.icon,
              state: skillTreeNodeState(node, unlockedNodeIds),
              onTap: () => onNodeTap(node),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/skill_tree_screen_test.dart`
Expected: PASS (3 testes).

- [ ] **Step 5: `flutter analyze`**

Run: `cd app && flutter analyze`
Expected: "No issues found!"

- [ ] **Step 6: Commit**

```bash
git add app/lib/ui/skill_tree_screen.dart app/test/skill_tree_screen_test.dart
git commit -m "Adiciona SkillTreeScreen (arvore visual completa)"
```

---

## Task 6: Full suite de widget-level check antes de mexer nos chamadores

**Files:** nenhum — task de checkpoint, sem mudança de código.

**Interfaces:** nenhuma.

- [ ] **Step 1: Rodar a suíte completa e confirmar baseline verde**

Run: `cd app && flutter test`
Expected: PASS — 133 testes no total (117 já existentes antes deste bloco + 3 de `allSkillTreeNodes`/`skillTreeBranchDisplayName` + 1 de `unlockedNodeIdsForCurrentPlayer` + 7 de `skill_tree_layout_test.dart` + 2 de `skill_tree_node_widget_test.dart` + 3 de `skill_tree_screen_test.dart`).

- [ ] **Step 2: `flutter analyze`**

Run: `cd app && flutter analyze`
Expected: "No issues found!"

(Nenhum commit nesta task — é só um checkpoint antes de tocar nas duas telas que usam `SkillTreeScreen`.)

---

## Task 7: `TrainingScreen` usa `SkillTreeScreen`

**Files:**
- Modify: `app/lib/ui/training_screen.dart:1-13` (imports), `:87-181` (`_openSkillTree` inteiro)
- Modify: `app/test/training_screen_test.dart` (o teste "unlocking Maestria da Brasa...")

**Interfaces:**
- Consumes: `SkillTreeScreen` (Task 5), `pixelSlideRoute` (já existente, Bloco 6).
- Produces: nada consumido por outras tasks.

- [ ] **Step 1: Confirmar a suíte atual passa antes de mexer (baseline)**

Run: `cd app && flutter test test/training_screen_test.dart`
Expected: PASS (5 testes).

- [ ] **Step 2: Trocar os imports**

Em `app/lib/ui/training_screen.dart`, substituir o bloco de imports inteiro:

```dart
import 'package:flutter/material.dart';

import '../game_domain/attack_event.dart';
import '../game_domain/battle_scene_view.dart';
import '../game_domain/element_catalog.dart';
import '../game_domain/training_match.dart';
import '../game_presentation/battle_scene_widget.dart';
import '../game_presentation/pixel_arena_background.dart';
import '../game_presentation/pixel_content_panel.dart';
import '../game_presentation/pixel_element_chip.dart';
import '../game_presentation/pixel_menu_button.dart';
import '../game_presentation/pixel_outlined_text.dart';
import '../game_presentation/pixel_sheet_panel.dart';
```

por:

```dart
import 'package:flutter/material.dart';

import '../game_domain/attack_event.dart';
import '../game_domain/battle_scene_view.dart';
import '../game_domain/element_catalog.dart';
import '../game_domain/training_match.dart';
import '../game_presentation/battle_scene_widget.dart';
import '../game_presentation/pixel_arena_background.dart';
import '../game_presentation/pixel_content_panel.dart';
import '../game_presentation/pixel_element_chip.dart';
import '../game_presentation/pixel_menu_button.dart';
import '../game_presentation/pixel_outlined_text.dart';
import '../game_presentation/pixel_page_route.dart';
import '../game_presentation/pixel_sheet_panel.dart';
import 'skill_tree_screen.dart';
```

- [ ] **Step 3: Substituir `_openSkillTree` inteiro**

Substituir o método `_openSkillTree` inteiro (do `void _openSkillTree() {` até o `}` que fecha o método, logo antes de `@override\n  Widget build`) por:

```dart
  Future<void> _openSkillTree() async {
    await Navigator.of(context).push(pixelSlideRoute((_) => SkillTreeScreen(
      title: 'Habilidades de ${_match.currentTurnName}',
      unlockedNodeIds: _match.unlockedNodeIdsForCurrentPlayer,
      canUnlockNow: true,
      onUnlock: (nodeId) async {
        try {
          _match.unlockSkillForCurrentPlayer(nodeId);
          return null;
        } on StateError catch (e) {
          return e.message;
        }
      },
    )));
    setState(() {});
  }
```

- [ ] **Step 4: Ajustar o teste "unlocking Maestria da Brasa..."**

Em `app/test/training_screen_test.dart`, substituir:

```dart
      await tester.tap(find.byIcon(Icons.auto_awesome));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('Desbloquear').first);
      await tester.pump();

      await tester.tap(find.text('Fechar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('Escolher elementos'));
```

por:

```dart
      await tester.tap(find.byIcon(Icons.auto_awesome));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('Maestria da Brasa'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('Desbloquear'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.byType(BackButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('Escolher elementos'));
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd app && flutter test test/training_screen_test.dart`
Expected: PASS (5 testes).

- [ ] **Step 6: `flutter analyze`**

Run: `cd app && flutter analyze`
Expected: "No issues found!"

- [ ] **Step 7: Commit**

```bash
git add app/lib/ui/training_screen.dart app/test/training_screen_test.dart
git commit -m "TrainingScreen usa SkillTreeScreen no lugar do modal antigo"
```

---

## Task 8: `MultiplayerBattleScreen` usa `SkillTreeScreen`

**Files:**
- Modify: `app/lib/ui/multiplayer_battle_screen.dart:1-20` (imports), `:145-244` (`_openSkillTree` inteiro)
- Modify: `app/test/multiplayer_battle_screen_test.dart:1-10` (imports), o teste "Habilidades modal..."

**Interfaces:**
- Consumes: `SkillTreeScreen` (Task 5).
- Produces: nada consumido por outras tasks.

- [ ] **Step 1: Confirmar a suíte atual passa antes de mexer (baseline)**

Run: `cd app && flutter test test/multiplayer_battle_screen_test.dart`
Expected: PASS (3 testes).

- [ ] **Step 2: Trocar os imports**

Em `app/lib/ui/multiplayer_battle_screen.dart`, substituir o bloco de imports inteiro:

```dart
import 'dart:async';

import 'package:flutter/material.dart';

import '../game_domain/attack_event.dart';
import '../game_domain/battle_scene_view.dart';
import '../game_domain/combination_catalog.dart';
import '../game_domain/detect_opponent_attack.dart';
import '../game_domain/element_catalog.dart';
import '../game_domain/multiplayer_exception.dart';
import '../game_domain/multiplayer_match.dart';
import '../game_domain/skill_tree_catalog.dart';
import '../game_presentation/battle_scene_widget.dart';
import '../game_presentation/pixel_arena_background.dart';
import '../game_presentation/pixel_content_panel.dart';
import '../game_presentation/pixel_element_chip.dart';
import '../game_presentation/pixel_menu_button.dart';
import '../game_presentation/pixel_outlined_text.dart';
import '../game_presentation/pixel_page_route.dart';
import '../game_presentation/pixel_sheet_panel.dart';
```

por (note que `'../game_domain/skill_tree_catalog.dart'` **sai** da lista —
nada mais no arquivo referencia `SkillNodeOption`/`availableSkillNodeOptions`
depois deste bloco, e deixá-lo quebraria `flutter analyze` com
`unused_import`):

```dart
import 'dart:async';

import 'package:flutter/material.dart';

import '../game_domain/attack_event.dart';
import '../game_domain/battle_scene_view.dart';
import '../game_domain/combination_catalog.dart';
import '../game_domain/detect_opponent_attack.dart';
import '../game_domain/element_catalog.dart';
import '../game_domain/multiplayer_exception.dart';
import '../game_domain/multiplayer_match.dart';
import '../game_presentation/battle_scene_widget.dart';
import '../game_presentation/pixel_arena_background.dart';
import '../game_presentation/pixel_content_panel.dart';
import '../game_presentation/pixel_element_chip.dart';
import '../game_presentation/pixel_menu_button.dart';
import '../game_presentation/pixel_outlined_text.dart';
import '../game_presentation/pixel_page_route.dart';
import '../game_presentation/pixel_sheet_panel.dart';
import 'skill_tree_screen.dart';
```

- [ ] **Step 3: Substituir `_openSkillTree` inteiro**

Substituir o método `_openSkillTree` inteiro (do `void _openSkillTree() {`
até o `}` que fecha o método, logo antes de `void _toggleElement`) por:

```dart
  Future<void> _openSkillTree() async {
    await Navigator.of(context).push(pixelSlideRoute((_) => SkillTreeScreen(
      title: 'Habilidades',
      unlockedNodeIds: _match.unlockedNodeIdsForMe,
      canUnlockNow: _match.isInProgress && _match.isMyTurn,
      onUnlock: (nodeId) async {
        try {
          await _match.unlockSkill(nodeId);
          return null;
        } on MultiplayerException catch (e) {
          return e.message;
        }
      },
    )));
    setState(() {});
  }
```

- [ ] **Step 4: Ajustar o teste "Habilidades modal..." (imports + corpo)**

Em `app/test/multiplayer_battle_screen_test.dart`, adicionar aos imports do
topo do arquivo (depois de `import 'package:app/game_presentation/pixel_menu_button.dart';`):

```dart
import 'package:app/game_presentation/skill_tree_layout.dart';
import 'package:app/game_presentation/skill_tree_node_widget.dart';
```

Substituir o corpo do teste `'Habilidades modal lists what can be unlocked
and unlocking it updates the list live'` a partir de `await tester.tap(find.byTooltip('Habilidades'));`
até o fim do `testWidgets` (mantendo a descrição do teste, o setup do
`client`/`match`/`pumpWidget` acima intactos):

```dart
      await tester.tap(find.byTooltip('Habilidades'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        tester.widget<SkillTreeNodeWidget>(
          find.widgetWithText(SkillTreeNodeWidget, 'Maestria da Brasa'),
        ).state,
        SkillTreeNodeState.available,
      );

      await tester.tap(find.text('Maestria da Brasa'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('Desbloquear'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        tester.widget<SkillTreeNodeWidget>(
          find.widgetWithText(SkillTreeNodeWidget, 'Maestria da Brasa'),
        ).state,
        SkillTreeNodeState.unlocked,
      );
      expect(
        tester.widget<SkillTreeNodeWidget>(
          find.widgetWithText(SkillTreeNodeWidget, 'Caminho do Incêndio'),
        ).state,
        SkillTreeNodeState.available,
      );

      await tester.tap(find.byType(BackButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpWidget(const SizedBox()); // dispose the poll Timer
    },
  );
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd app && flutter test test/multiplayer_battle_screen_test.dart`
Expected: PASS (3 testes).

- [ ] **Step 6: `flutter analyze`**

Run: `cd app && flutter analyze`
Expected: "No issues found!" (confirma em particular que o `unused_import`
não disparou).

- [ ] **Step 7: Commit**

```bash
git add app/lib/ui/multiplayer_battle_screen.dart app/test/multiplayer_battle_screen_test.dart
git commit -m "MultiplayerBattleScreen usa SkillTreeScreen no lugar do modal antigo"
```

---

## Task 9: Suíte completa, verificação manual e registro da decisão

**Files:**
- Modify: `DECISIONS.md` (nova `## DECISION-038`)
- Modify: `TASKS.md` (linha `DONE` nova)

**Interfaces:**
- Consumes: tudo das Tasks 1-8.
- Produces: nada (última task do bloco).

- [ ] **Step 1: Rodar a suíte completa do app**

Run: `cd app && flutter test`
Expected: PASS — 133 testes no total.

- [ ] **Step 2: `flutter analyze` na árvore final**

Run: `cd app && flutter analyze`
Expected: "No issues found!"

- [ ] **Step 3: Verificação manual no navegador**

Reiniciar o servidor de preview do zero (parar o processo anterior se
algum estiver rodando e iniciar de novo — **não** só recarregar a aba,
lição do Bloco 3):

1. Abrir o Modo Treino, tocar "Habilidades": confirmar que abre uma tela
   cheia (não mais um bottom sheet), com as 5 branches (Fogo, Precisão,
   Elemental, Vitalidade, Defesa) visíveis, roláveis horizontalmente.
2. Tocar num nó disponível (ex: "Maestria da Brasa"): confirmar que o
   painel de detalhe sobe com nome/descrição/botão "Desbloquear".
   Desbloquear de verdade — confirmar que o círculo vira dourado e que
   "Caminho do Incêndio" (próximo da cadeia) vira tocável.
3. Tocar num nó travado (antes de desbloquear seu pré-requisito):
   confirmar que o painel mostra "Requer: ..." sem botão.
4. Voltar (seta de voltar da AppBar) pra tela de batalha — confirmar que
   o HUD reflete qualquer bônus imediato (ex: desbloquear Treino de
   Vitalidade e ver o HP máximo subir).
5. Repetir no Multiplayer contra o backend real: abrir Habilidades,
   confirmar que a árvore aparece mesmo fora da vez (mostrando "Só dá pra
   desbloquear na sua vez." ao tocar um nó disponível), e desbloquear de
   verdade na própria vez.
6. Checar o console do navegador: sem exceções novas.

- [ ] **Step 4: Registrar `DECISION-038` em `DECISIONS.md`**

Adicionar ao final do arquivo, seguindo o formato das decisões anteriores:

```markdown
## DECISION-038
Data: 2026-09-10
Decisão: Skill Tree visual (Bloco 7 da direção de produto) — o botão
"Habilidades" (Treino e Multiplayer) passa a abrir uma tela cheia com a
árvore inteira (travados/disponíveis/desbloqueados juntos, ícone por nó,
5 branches lado a lado roláveis horizontalmente) em vez do modal com só
os "disponíveis agora". Uma única `SkillTreeScreen` substitui as duas
implementações quase idênticas que existiam antes.
Passos: `SkillTreeNodeOption`/`allSkillTreeNodes`/`skillTreeBranchDisplayName`
novos em `game_domain/skill_tree_catalog.dart` (ícone por nó — emoji,
mesmo espírito do symbol de `ElementOption` — e nome de exibição por
branch), sem tocar `battle_engine`/backend. `TrainingMatch` ganhou
`unlockedNodeIdsForCurrentPlayer` (só tinha os "disponíveis agora" antes).
Layout puro (`orderBranchNodes`/`skillTreeNodeState`, testáveis sem
Flutter) assume que cada branch é uma cadeia linear — cobre 100% do
conteúdo real hoje; se um nó ganhar 2+ pré-requisitos/filhos no futuro,
ainda produz uma ordem topológica válida, só não desenha ramificação
visual (limitação conhecida, documentada no design). Cada branch vira uma
coluna própria — nenhuma raiz falsa inventada pra unificar visualmente.
Tocar qualquer nó (`SkillTreeNodeWidget`, círculo com ícone) abre um
painel de detalhe (`PixelSheetPanel`) com nome/descrição e, dependendo do
estado, os pré-requisitos que faltam, o botão "Desbloquear", ou o aviso
de que só dá pra desbloquear na própria vez. Mudança de UX deliberada: a
árvore inteira agora fica visível a qualquer momento no Multiplayer,
mesmo fora da vez — só a ação de desbloquear continua condicionada a
isso (antes, fora da vez, nem a lista aparecia).
Motivo: Bloco 7 da nova direção de produto (game feel) — o usuário trouxe
uma imagem de referência de árvore de habilidades visual; decidido em
brainstorming não inventar uma raiz falsa (os dados reais não têm uma
raiz compartilhada entre as 5 branches) e usar tela cheia em vez de
continuar no painel que sobe de baixo.
Consequência: nenhuma lacuna nova conhecida além da já documentada
(layout assume cadeia linear). `SkillNodeOption`/`skillNodeOptionFrom`/
`availableSkillNodeOptions` (código antigo) continuam existindo, sem uso
depois deste bloco — não removidos, fora de escopo.
Testes: suíte completa do app (`flutter test`, 133 testes) e `flutter
analyze` passando. Verificado de ponta a ponta de verdade via `flutter
run -d web-server` (servidor reiniciado, não só recarregado): árvore
completa visível no Treino, nó travado mostrando pré-requisitos, nó
disponível desbloqueado de verdade com HUD atualizando (HP máximo subiu
com Treino de Vitalidade), e no Multiplayer a árvore visível fora da vez
com o aviso correto ao tentar desbloquear.
```

- [ ] **Step 5: Atualizar `TASKS.md`**

Adicionar ao final da seção `# DONE`:

```markdown
- Skill Tree visual (Bloco 7 da direção de produto): `SkillTreeScreen`
  única (Treino e Multiplayer) substitui o modal de "disponíveis agora"
  por uma árvore completa — travados/disponíveis/desbloqueados juntos,
  ícone por nó, 5 branches lado a lado roláveis, painel de detalhe ao
  tocar um nó (DECISION-038)
```

Na seção `# BACKLOG`, sub-seção "App Flutter (app/)", adicionar:

```markdown
- Layout da Skill Tree visual (DECISION-038) assume que cada branch é
  uma cadeia linear (`orderBranchNodes`) — se um nó ganhar 2+
  pré-requisitos ou 2+ nós dependendo dele no futuro, o layout continua
  correto logicamente mas não desenha a ramificação visualmente
```

- [ ] **Step 6: Commit**

```bash
git add DECISIONS.md TASKS.md
git commit -m "Registra DECISION-038 e atualiza TASKS.md (skill tree visual)"
```

- [ ] **Step 7: Finalizar o bloco**

Announce: "I'm using the finishing-a-development-branch skill to complete this work."
**REQUIRED SUB-SKILL:** Use superpowers:finishing-a-development-branch — rodar a suíte final, apresentar as opções, executar a escolha do usuário.

---

## Self-Review

**1. Cobertura da spec:** "Sem raiz falsa" → Task 5 (`SkillTreeScreen` gera uma `_BranchColumn` por branch real, sem nó sintético). "Tela cheia" → Tasks 7/8 (`pixelSlideRoute`, não mais `showModalBottomSheet` pro botão "Habilidades"). "Layout linear, limitação documentada" → Task 3 (`orderBranchNodes`) + DECISION-038 + BACKLOG. "Dados novos só em game_domain" → Task 1, zero mudança em `battle_engine`/backend. "Mudança de UX: árvore sempre visível" → Task 8 (`canUnlockNow` só afeta o botão dentro do painel, não a visibilidade da árvore). "Consequência em testes" → Tasks 7/8, before/depois exatos dos dois testes afetados. Nenhuma decisão da spec ficou sem task.

**2. Placeholder scan:** Nenhum "TBD"/"implementar depois" — todo código é completo e colável direto, inclusive os trechos de teste reescritos nas Tasks 7/8.

**3. Consistência de tipos:** `SkillTreeNodeOption(id, name, description, branch, prerequisites, icon)` (Task 1) usado identicamente em `orderBranchNodes`/`skillTreeNodeState` (Task 3), `SkillTreeScreen`/`_BranchColumn` (Task 5) e nos testes (Tasks 3, 5). `SkillTreeNodeState` (Task 3) usado identicamente em `SkillTreeNodeWidget.state` (Task 4) e nas asserções das Tasks 5/7/8. `SkillTreeScreen({title, unlockedNodeIds, canUnlockNow, onUnlock})` (Task 5) usado com a mesma assinatura nas Tasks 7 e 8 — `onUnlock` sempre `Future<String?> Function(String nodeId)`, `null` = sucesso, `String` = mensagem de erro, em ambos os chamadores.
