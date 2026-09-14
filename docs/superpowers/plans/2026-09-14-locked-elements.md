# Elementos bloqueados no Modo Treino (Bloco 2b) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Each Modo Treino player picks 2 starting elements once; the other 8 unlock via a new Skill Tree branch, gated by cumulative turns played (not just prerequisites like every other node today).

**Architecture:** Reuses the existing `SkillGrant`/`SkillProgress`/`SkillTree` machinery in `packages/battle_engine` (new `ElementUnlock` grant kind, new "elementos" branch) — no changes to `BattleState`/`TurnEngine` or the backend. The turns-played gate lives entirely in `TrainingMatch` (Game Domain), which is the only layer that knows about cumulative, persisted turn counts.

**Tech Stack:** Dart (`packages/battle_engine`), Flutter (`app/`) — same stack as every prior block this session. No TypeScript/backend changes.

**Spec:** `docs/superpowers/specs/2026-09-14-locked-elements-design.md`

## Global Constraints

- Scope is **Modo Treino only** — never touch `BattleState`, `TurnEngine`, or `backend/src/battle-rules/` in this plan.
- Starting pick: exactly 2 elements, chosen once per player slot (`'a'`/`'b'`), free, no cost.
- Unlock cost formula for the Nth element beyond the starting 2: `(E - 1) × 10` cumulative turns played, where `E` = elements already granted **before** this attempt (counting the 2 starting ones). 10 for the 3rd element, 20 for the 4th, 30 for the 5th, etc.
- The cumulative turns-played counter persists across matches (survives "Nova partida", like Skill Tree/Discovery Book) — it is **not** the existing ephemeral `_turnsPlayed` field, which stays untouched.
- UI never imports a `battle_engine` type directly outside `game_domain`/`battle_engine` itself (DECISION-011/017) — `TrainingScreen`/`ElementStarterScreen` reason about element/node ids as plain strings, using the `'unlock_<elementId>'` naming convention rather than referencing `ElementUnlocks`.
- Every task ends with its own file's tests green before moving to the next task.

---

### Task 1: `ElementUnlock` + `ElementUnlocks` (Dart)

**Files:**
- Create: `packages/battle_engine/lib/src/element_unlock.dart`
- Create: `packages/battle_engine/lib/src/element_unlocks.dart`
- Create: `packages/battle_engine/test/element_unlock_test.dart`
- Create: `packages/battle_engine/test/element_unlocks_test.dart`
- Modify: `packages/battle_engine/lib/battle_engine.dart`

**Interfaces:**
- Produces: `class ElementUnlock implements SkillGrant { final String id; final String elementId; }`; `class ElementUnlocks { static const List<ElementUnlock> all; static const fire, water, wind, ice, nature, lightning, earth, shadow, light, poison; }`.

- [ ] **Step 1: Write the failing tests**

Create `packages/battle_engine/test/element_unlock_test.dart`:

```dart
import 'package:battle_engine/battle_engine.dart';
import 'package:test/test.dart';

void main() {
  group('ElementUnlock', () {
    test('two unlocks with the same id are equal', () {
      const a = ElementUnlock(id: 'x', elementId: 'fire');
      const b = ElementUnlock(id: 'x', elementId: 'water');
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('holds the elementId it was constructed with', () {
      const unlock = ElementUnlock(id: 'unlock_fire', elementId: 'fire');
      expect(unlock.elementId, equals('fire'));
    });
  });
}
```

Create `packages/battle_engine/test/element_unlocks_test.dart`:

```dart
import 'package:battle_engine/battle_engine.dart';
import 'package:test/test.dart';

void main() {
  group('ElementUnlocks', () {
    test('has exactly one entry per built-in element', () {
      expect(ElementUnlocks.all.length, equals(Elements.all.length));
      final elementIds = ElementUnlocks.all.map((u) => u.elementId).toSet();
      expect(elementIds, equals(Elements.all.map((e) => e.id).toSet()));
    });

    test('all built-in unlocks have unique ids', () {
      final ids = ElementUnlocks.all.map((u) => u.id).toSet();
      expect(ids.length, equals(ElementUnlocks.all.length));
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd packages/battle_engine && dart test test/element_unlock_test.dart test/element_unlocks_test.dart`
Expected: FAIL — `ElementUnlock`/`ElementUnlocks` are not defined yet.

- [ ] **Step 3: Write the implementation**

Create `packages/battle_engine/lib/src/element_unlock.dart`:

```dart
import 'skill_grant.dart';

/// A [SkillGrant] that unlocks a specific element for use — the
/// build-level counterpart to [Mutation]/[CombinationModifier]/
/// [MaxHpBonus]. Plain data; [SkillProgress.grantedElementIds] collects
/// which elements a player can currently play with. `SkillTree`/
/// `SkillProgress` themselves stay unaware of any turns-played gate —
/// that's enforced one layer up, by `TrainingMatch` (see Bloco 2b,
/// DECISION-047), since it needs persisted, cross-match state this
/// engine has no concept of.
class ElementUnlock implements SkillGrant {
  @override
  final String id;
  final String elementId;

  const ElementUnlock({required this.id, required this.elementId});

  @override
  bool operator ==(Object other) => other is ElementUnlock && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'ElementUnlock($id)';
}
```

Create `packages/battle_engine/lib/src/element_unlocks.dart`:

```dart
import 'element_unlock.dart';

/// Built-in element unlocks, one per element in `Elements.all` — used by
/// `defaultSkillTree`'s "elementos" branch (Bloco 2b, DECISION-047). Node
/// ids follow the `'unlock_<elementId>'` convention — `TrainingScreen`
/// relies on that same convention (as plain strings, never importing this
/// class) to know when a player still needs to make their starting pick.
class ElementUnlocks {
  ElementUnlocks._();

  static const fire = ElementUnlock(id: 'unlock_fire', elementId: 'fire');
  static const water = ElementUnlock(id: 'unlock_water', elementId: 'water');
  static const wind = ElementUnlock(id: 'unlock_wind', elementId: 'wind');
  static const ice = ElementUnlock(id: 'unlock_ice', elementId: 'ice');
  static const nature = ElementUnlock(id: 'unlock_nature', elementId: 'nature');
  static const lightning = ElementUnlock(id: 'unlock_lightning', elementId: 'lightning');
  static const earth = ElementUnlock(id: 'unlock_earth', elementId: 'earth');
  static const shadow = ElementUnlock(id: 'unlock_shadow', elementId: 'shadow');
  static const light = ElementUnlock(id: 'unlock_light', elementId: 'light');
  static const poison = ElementUnlock(id: 'unlock_poison', elementId: 'poison');

  static const List<ElementUnlock> all = [
    fire, water, wind, ice, nature, lightning, earth, shadow, light, poison,
  ];
}
```

In `packages/battle_engine/lib/battle_engine.dart`, add two exports right after `export 'src/skill_grant.dart';`:

```dart
export 'src/skill_grant.dart';
export 'src/element_unlock.dart';
export 'src/element_unlocks.dart';
export 'src/ability_effect.dart';
```

(The rest of the file — every other export line — stays exactly as it is today.)

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd packages/battle_engine && dart test test/element_unlock_test.dart test/element_unlocks_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add packages/battle_engine/lib/src/element_unlock.dart packages/battle_engine/lib/src/element_unlocks.dart packages/battle_engine/lib/battle_engine.dart packages/battle_engine/test/element_unlock_test.dart packages/battle_engine/test/element_unlocks_test.dart
git commit -m "$(cat <<'EOF'
Adiciona ElementUnlock/ElementUnlocks (Bloco 2b, elementos bloqueados)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: `defaultSkillTree` ganha a branch "elementos"

**Files:**
- Modify: `packages/battle_engine/lib/src/default_skill_tree.dart`
- Modify: `packages/battle_engine/test/default_skill_tree_test.dart`

**Interfaces:**
- Consumes: `ElementUnlocks.all` (Task 1).
- Produces: 10 new `SkillNode`s in `defaultSkillTree`, ids `'unlock_fire'`, `'unlock_water'`, ..., `'unlock_poison'`, branch `'elementos'`, no prerequisites.

- [ ] **Step 1: Write the failing test**

In `packages/battle_engine/test/default_skill_tree_test.dart`, add two tests at the end of `main()` (before the closing `}`):

```dart
  test('elementos branch has one node per built-in element, no '
      'prerequisites', () {
    final elementNodes =
        defaultSkillTree.nodes.where((n) => n.branch == 'elementos');
    expect(elementNodes.length, equals(Elements.all.length));
    expect(elementNodes.every((n) => n.prerequisites.isEmpty), isTrue);
  });

  test('unlocking an elementos node grants the matching elementId', () {
    final progress =
        SkillProgress(defaultSkillTree).unlock('unlock_fire');
    expect(progress.grantedElementIds, equals(['fire']));
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/battle_engine && dart test test/default_skill_tree_test.dart`
Expected: FAIL — no node has branch `'elementos'` yet, and `grantedElementIds` doesn't exist yet either (Task 3 adds it — this second test will only go green once both this task and Task 3 land; for now confirm the failure is about the missing branch/nodes, not a typo).

- [ ] **Step 3: Add the branch to `defaultSkillTree`**

Replace the full content of `packages/battle_engine/lib/src/default_skill_tree.dart` with:

```dart
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
```

- [ ] **Step 4: Run test to verify it passes (partially)**

Run: `cd packages/battle_engine && dart test test/default_skill_tree_test.dart`
Expected: the first new test (`elementos branch has one node...`) PASSES. The second new test (`unlocking an elementos node grants...`) still FAILS — `SkillProgress.grantedElementIds` doesn't exist until Task 3. This is expected; do not skip ahead to fix it here.

- [ ] **Step 5: Run the rest of the package's suite to confirm no other ripple**

Run: `cd packages/battle_engine && dart test`
Expected: only the one still-pending test from Step 4 fails; everything else (including `skill_tree_test.dart`, `skill_progress_test.dart`, `ability_engine_test.dart`, `turn_engine_test.dart`) passes unchanged — adding a branch with unrelated, prerequisite-free nodes doesn't affect any existing tree/progress logic.

- [ ] **Step 6: Commit**

```bash
git add packages/battle_engine/lib/src/default_skill_tree.dart packages/battle_engine/test/default_skill_tree_test.dart
git commit -m "$(cat <<'EOF'
defaultSkillTree ganha a branch elementos (Bloco 2b)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: `SkillProgress.grantedElementIds`

**Files:**
- Modify: `packages/battle_engine/lib/src/skill_progress.dart`
- Modify: `packages/battle_engine/test/skill_progress_test.dart`

**Interfaces:**
- Consumes: `ElementUnlock` (Task 1).
- Produces: `SkillProgress.grantedElementIds` (`List<String>`).

- [ ] **Step 1: Write the failing tests**

In `packages/battle_engine/test/skill_progress_test.dart`, the local `buildTree()` helper (used by every test in this file) needs one more node so the new getter has something to exercise. Replace the full content of `buildTree()`'s body with:

```dart
  SkillTree buildTree() {
    return SkillTree([
      SkillNode(
        id: 'ember_mastery',
        name: 'Maestria da Brasa',
        description: 'x',
        branch: 'fogo',
        grants: Mutations.combustion,
      ),
      SkillNode(
        id: 'wildfire_path',
        name: 'Caminho do Incêndio',
        description: 'x',
        branch: 'fogo',
        prerequisites: ['ember_mastery'],
        grants: Mutations.wildfire,
      ),
      SkillNode(
        id: 'unstable_core_training',
        name: 'Treino do Núcleo Instável',
        description: 'x',
        branch: 'precisao',
        grants: Mutations.unstableCore,
      ),
      SkillNode(
        id: 'elemental_insight',
        name: 'Percepção Elemental',
        description: 'x',
        branch: 'elemental',
        grants: CombinationModifiers.propagation,
      ),
      SkillNode(
        id: 'vitality_training',
        name: 'Treino de Vitalidade',
        description: 'x',
        branch: 'vitalidade',
        grants: MaxHpBonuses.vitality,
      ),
      SkillNode(
        id: 'unlock_fire',
        name: 'Fogo',
        description: 'x',
        branch: 'elementos',
        grants: const ElementUnlock(id: 'unlock_fire', elementId: 'fire'),
      ),
    ]);
  }
```

This adds one new root node (`unlock_fire`), so the existing "lists every branch root before anything is unlocked" test (inside `group('SkillProgress.availableNodes', ...)`) needs its expected set updated too — replace it with:

```dart
    test('lists every branch root before anything is unlocked', () {
      final progress = SkillProgress(buildTree());
      expect(
        progress.availableNodes.map((n) => n.id).toSet(),
        equals({
          'ember_mastery',
          'unstable_core_training',
          'elemental_insight',
          'vitality_training',
          'unlock_fire',
        }),
      );
    });
```

Add a new group at the end of `main()`, right before the closing `}`:

```dart
  group('SkillProgress.grantedElementIds', () {
    test('is empty with nothing unlocked', () {
      final progress = SkillProgress(buildTree());
      expect(progress.grantedElementIds, isEmpty);
    });

    test('reflects an unlocked ElementUnlock node', () {
      final progress = SkillProgress(buildTree()).unlock('unlock_fire');
      expect(progress.grantedElementIds, equals(['fire']));
    });

    test('ignores nodes that grant a Mutation, CombinationModifier or '
        'MaxHpBonus', () {
      final progress = SkillProgress(buildTree()).unlock('ember_mastery');
      expect(progress.grantedElementIds, isEmpty);
    });
  });
```

- [ ] **Step 2: Run tests to verify the expected failures**

Run: `cd packages/battle_engine && dart test test/skill_progress_test.dart`
Expected: the updated "lists every branch root..." test PASSES (it only depends on `availableNodes`, already implemented); the three new `grantedElementIds` tests FAIL — the getter doesn't exist yet.

- [ ] **Step 3: Implement `grantedElementIds`**

In `packages/battle_engine/lib/src/skill_progress.dart`, add the import:

```dart
import 'combination_modifier.dart';
import 'element_unlock.dart';
import 'max_hp_bonus.dart';
import 'mutation.dart';
import 'skill_node.dart';
import 'skill_tree.dart';
```

Add the new getter right after `grantedMaxHpBonus` and before the private `_grantedOfType` helper:

```dart
  /// Sum of every [MaxHpBonus] granted by unlocked nodes (nodes that grant
  /// a [Mutation] or [CombinationModifier] instead are skipped),
  /// deduplicated by id before summing.
  int get grantedMaxHpBonus {
    return _grantedOfType<MaxHpBonus>((grant) => grant.id)
        .fold<int>(0, (sum, bonus) => sum + bonus.bonus);
  }

  /// Element ids granted by unlocked nodes (nodes that grant something
  /// else are skipped), in unlock order, deduplicated by id.
  List<String> get grantedElementIds {
    return _grantedOfType<ElementUnlock>((grant) => grant.id)
        .map((grant) => grant.elementId)
        .toList();
  }

  List<T> _grantedOfType<T>(String Function(T) idOf) {
```

(Everything else in the file — the rest of `_grantedOfType` and everything above `grantedMaxHpBonus` — stays exactly as it is today.)

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd packages/battle_engine && dart test test/skill_progress_test.dart`
Expected: PASS (all tests in the file, including the 3 new ones).

- [ ] **Step 5: Run the full package suite, including Task 2's pending test**

Run: `cd packages/battle_engine && dart analyze && dart test`
Expected: `No issues found!`, all tests PASS — including `default_skill_tree_test.dart`'s "unlocking an elementos node grants the matching elementId" test, now unblocked by this task.

- [ ] **Step 6: Commit**

```bash
git add packages/battle_engine/lib/src/skill_progress.dart packages/battle_engine/test/skill_progress_test.dart
git commit -m "$(cat <<'EOF'
SkillProgress ganha grantedElementIds (Bloco 2b)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: `TrainingProgressStore` ganha turnos cumulativos

**Files:**
- Modify: `app/lib/game_domain/training_progress_store.dart`
- Modify: `app/test/game_domain/training_progress_store_test.dart`

**Interfaces:**
- Produces: `TrainingProgressStore.loadTurnsPlayed(String slot) -> Future<int>`; `TrainingProgressStore.saveTurnsPlayed(String slot, int turnsPlayed) -> Future<void>`.

- [ ] **Step 1: Write the failing tests**

In `app/test/game_domain/training_progress_store_test.dart`, add a new group at the end of `main()`, right before the closing `}`:

```dart
  group('turns played', () {
    test('an empty slot returns 0', () async {
      final store = TrainingProgressStore();
      expect(await store.loadTurnsPlayed('a'), 0);
    });

    test('saves and reloads a slot', () async {
      final store = TrainingProgressStore();
      await store.saveTurnsPlayed('a', 7);

      expect(await store.loadTurnsPlayed('a'), 7);
    });

    test('two slots are independent', () async {
      final store = TrainingProgressStore();
      await store.saveTurnsPlayed('a', 10);
      await store.saveTurnsPlayed('b', 3);

      expect(await store.loadTurnsPlayed('a'), 10);
      expect(await store.loadTurnsPlayed('b'), 3);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/game_domain/training_progress_store_test.dart`
Expected: FAIL — `loadTurnsPlayed`/`saveTurnsPlayed` don't exist yet.

- [ ] **Step 3: Implement the two methods**

Replace the full content of `app/lib/game_domain/training_progress_store.dart` with:

```dart
import 'package:shared_preferences/shared_preferences.dart';

/// Persiste o progresso do Modo Treino (Skill Tree por slot `'a'`/`'b'`,
/// Livro de Descobertas compartilhado, turnos jogados cumulativos por
/// slot — Bloco 2b) entre partidas e entre execuções do app —
/// `shared_preferences`, local ao aparelho, sem rede, sem custo.
class TrainingProgressStore {
  static const _unlockedKeyPrefix = 'training_unlocked_';
  static const _discoveredKey = 'training_discovered';
  static const _turnsPlayedKeyPrefix = 'training_turns_played_';

  Future<List<String>> loadUnlockedNodeIds(String slot) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('$_unlockedKeyPrefix$slot') ?? const [];
  }

  Future<void> saveUnlockedNodeIds(String slot, List<String> unlockedNodeIds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('$_unlockedKeyPrefix$slot', unlockedNodeIds);
  }

  Future<List<String>> loadDiscoveredCombinationIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_discoveredKey) ?? const [];
  }

  Future<void> saveDiscoveredCombinationIds(List<String> discoveredCombinationIds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_discoveredKey, discoveredCombinationIds);
  }

  /// Turnos cumulativos jogados por [slot] (`'a'`/`'b'`), desde sempre —
  /// não reseta em "Nova partida" (Bloco 2b: gate de desbloqueio de
  /// elementos). `0` se nunca salvo.
  Future<int> loadTurnsPlayed(String slot) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_turnsPlayedKeyPrefix$slot') ?? 0;
  }

  Future<void> saveTurnsPlayed(String slot, int turnsPlayed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_turnsPlayedKeyPrefix$slot', turnsPlayed);
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd app && flutter test test/game_domain/training_progress_store_test.dart`
Expected: PASS (all tests in the file).

- [ ] **Step 5: Commit**

```bash
git add app/lib/game_domain/training_progress_store.dart app/test/game_domain/training_progress_store_test.dart
git commit -m "$(cat <<'EOF'
TrainingProgressStore ganha turnos cumulativos por slot (Bloco 2b)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: `TrainingMatch` — gate de elementos bloqueados

**Files:**
- Modify: `app/lib/game_domain/training_match.dart`
- Modify: `app/test/game_domain/training_match_test.dart` (extensive — most existing tests play elements that are now locked by default, same ripple pattern as Bloco 2a's AP mechanic)

**Interfaces:**
- Consumes: `ElementUnlock`, `ElementUnlocks` (Task 1), `SkillProgress.grantedElementIds` (Task 3).
- Produces: `TrainingMatch({..., int initialTurnsPlayedA = 0, int initialTurnsPlayedB = 0})`; `TrainingMatch.fromPersistedProgress({..., required int turnsPlayedA, required int turnsPlayedB})`; `List<String> get availableElementIdsForCurrentPlayer`; `int get cumulativeTurnsPlayedA`; `int get cumulativeTurnsPlayedB`; `int? turnsRemainingToUnlock(String nodeId)`; `playElementIds` now throws `ArgumentError` for a locked element; `unlockSkillForCurrentPlayer` now throws `StateError` for an `ElementUnlock` node without enough cumulative turns.

**Why this is the biggest task**: once `playElementIds` defensively rejects an element the current player hasn't been granted, and a bare `TrainingMatch()` starts with **zero** granted elements (nothing seeds the starting pick), every existing test that constructs a bare `TrainingMatch()` and immediately plays an element breaks — by design, the same way Bloco 2a's AP cost broke every test that combo'd for free. Fix strategy: a shared `_allElementsUnlocked()` helper seeds generous access for tests that aren't specifically about element-locking; tests that check exact `unlockedNodeIds` contents, or are specifically about the new gate, seed narrowly instead.

- [ ] **Step 1: Rewrite `training_match_test.dart` in full**

Replace the full content of `app/test/game_domain/training_match_test.dart` with:

```dart
import 'package:app/game_domain/effect_badge_view.dart';
import 'package:app/game_domain/training_match.dart';
import 'package:battle_engine/battle_engine.dart';
import 'package:flutter_test/flutter_test.dart';

SkillProgress _allElementsUnlocked() => SkillProgress(
      defaultSkillTree,
      unlockedNodeIds: ElementUnlocks.all.map((u) => u.id).toList(),
    );

void main() {
  test('starts with Jogador A to act and nothing discovered', () {
    final match = TrainingMatch();

    expect(match.currentTurnName, equals('Jogador A'));
    expect(match.discoveredCount, equals(0));
    expect(match.totalCombinationsCount, greaterThan(0));
    expect(match.activeFieldEffectNames, isEmpty);
    expect(match.lastTriggeredCombinationName, isNull);
  });

  test('playing fire+wind triggers Tempestade Ígnea and passes the turn',
      () {
    final match = TrainingMatch(
      initialApA: const ApPool(max: 5, current: 3),
      initialProgressA: _allElementsUnlocked(),
    );

    match.playElementIds(['fire', 'wind']);

    expect(match.currentTurnName, equals('Jogador B'));
    expect(match.lastTriggeredCombinationName, equals('Tempestade Ígnea'));
    expect(match.activeFieldEffectNames, equals(['Tempestade Ígnea']));
    expect(match.discoveredCount, equals(1));
  });

  test('discovering the same combination twice does not double-count', () {
    final match = TrainingMatch(
      initialApA: const ApPool(max: 5, current: 3),
      initialApB: const ApPool(max: 5, current: 3),
      initialProgressA: _allElementsUnlocked(),
      initialProgressB: _allElementsUnlocked(),
    );

    match.playElementIds(['fire', 'wind']); // Jogador A
    match.playElementIds(['fire', 'wind']); // Jogador B, same combo

    expect(match.discoveredCount, equals(1));
  });

  test('an unknown combination does not add a field effect but still '
      'passes the turn', () {
    final match = TrainingMatch(
      initialApA: const ApPool(max: 5, current: 3),
      initialProgressA: _allElementsUnlocked(),
    );

    match.playElementIds(['ice', 'shadow']);

    expect(match.lastTriggeredCombinationName, isNull);
    expect(match.activeFieldEffectNames, isEmpty);
    expect(match.currentTurnName, equals('Jogador B'));
  });

  test('throws for an unknown element id', () {
    final match = TrainingMatch();
    expect(() => match.playElementIds(['ghost']), throwsArgumentError);
  });

  group('skill tree integration', () {
    test('unlocking a node adds it to the current player\'s granted list',
        () {
      final match = TrainingMatch();
      match.unlockSkillForCurrentPlayer('ember_mastery');

      expect(
        match.unlockedGrantNamesForCurrentPlayer,
        contains('Combustão'),
      );
    });

    test('unlocking a node makes its dependents available', () {
      final match = TrainingMatch();
      expect(
        match.availableSkillNodesForCurrentPlayer
            .map((n) => n.id),
        isNot(contains('wildfire_path')),
      );

      match.unlockSkillForCurrentPlayer('ember_mastery');

      expect(
        match.availableSkillNodesForCurrentPlayer.map((n) => n.id),
        contains('wildfire_path'),
      );
    });

    test('throws when trying to unlock a node whose prerequisite is '
        'missing', () {
      final match = TrainingMatch();
      expect(
        () => match.unlockSkillForCurrentPlayer('wildfire_path'),
        throwsStateError,
      );
    });

    test('a mutation unlocked by Jogador A applies to every action they '
        'take, hitting the opponent', () {
      final match = TrainingMatch(initialProgressA: _allElementsUnlocked());
      match.unlockSkillForCurrentPlayer('ember_mastery'); // Jogador A

      match.playElementIds(['fire']);

      expect(match.lastAppliedStatusNames, contains('Queimadura'));
      expect(match.playerBStatusNames, contains('Queimadura'));
      expect(match.playerAStatusNames, isEmpty);
    });

    test('each player\'s unlocked skills are independent', () {
      final match = TrainingMatch(initialProgressA: _allElementsUnlocked());
      match.unlockSkillForCurrentPlayer('ember_mastery'); // Jogador A
      expect(match.unlockedGrantNamesForCurrentPlayer, contains('Combustão'));

      match.playElementIds(['fire']); // turn passes to Jogador B

      // Jogador B hasn't unlocked anything yet.
      expect(match.unlockedGrantNamesForCurrentPlayer, isEmpty);
    });

    test('unlockedNodeIdsForCurrentPlayer reflects what the current player has unlocked', () {
      final match = TrainingMatch();

      expect(match.unlockedNodeIdsForCurrentPlayer, isEmpty);

      match.unlockSkillForCurrentPlayer('ember_mastery');

      expect(match.unlockedNodeIdsForCurrentPlayer, ['ember_mastery']);
    });
  });

  group('HP and victory', () {
    test('both players start at 100/100 HP', () {
      final match = TrainingMatch();
      expect(match.playerAMaxHp, equals(100));
      expect(match.playerACurrentHp, equals(100));
      expect(match.playerBMaxHp, equals(100));
      expect(match.playerBCurrentHp, equals(100));
    });

    test('a triggered combination reduces the opponent\'s current HP', () {
      final match = TrainingMatch(
        initialApA: const ApPool(max: 5, current: 3),
        initialProgressA: _allElementsUnlocked(),
      );
      match.playElementIds(['fire', 'wind']); // Jogador A, 20 damage
      expect(match.playerBCurrentHp, equals(80));
    });

    test('is not over and has no winner while both are alive', () {
      final match = TrainingMatch();
      expect(match.isOver, isFalse);
      expect(match.winnerName, isNull);
    });

    test('ends the match and names the winner once someone reaches 0 HP',
        () {
      final match = TrainingMatch(
        initialProgressA: _allElementsUnlocked(),
        initialProgressB: _allElementsUnlocked(),
      );
      // 5 basic damage per hit (single element, always free) — 20 hits
      // defeat 100 HP. Jogador A acts first each round, so their 20th
      // hit lands before Jogador B's 20th.
      for (var i = 0; i < 19; i++) {
        match.playElementIds(['fire']); // Jogador A
        match.playElementIds(['ice']); // Jogador B
      }
      match.playElementIds(['fire']); // Jogador A's 20th hit defeats Jogador B

      expect(match.isOver, isTrue);
      expect(match.winnerName, equals('Jogador A'));
      expect(match.playerBCurrentHp, equals(0));
    });

    test('unlocking Treino de Vitalidade raises current player\'s max and '
        'current HP by 20 immediately', () {
      final match = TrainingMatch();
      match.unlockSkillForCurrentPlayer('vitality_training'); // Jogador A

      expect(match.playerAMaxHp, equals(120));
      expect(match.playerACurrentHp, equals(120));
      expect(match.playerBMaxHp, equals(100));
    });

    test('a Vitalidade bonus unlocked mid-match does not affect prior '
        'damage taken', () {
      final match = TrainingMatch(
        initialApA: const ApPool(max: 5, current: 3),
        initialProgressA: _allElementsUnlocked(),
      );
      match.playElementIds(['fire', 'wind']); // Jogador A hits B for 20
      // Now it's Jogador B's turn; they unlock Vitalidade for themselves.
      match.unlockSkillForCurrentPlayer('vitality_training');

      expect(match.playerBMaxHp, equals(120));
      expect(match.playerBCurrentHp, equals(100)); // 80 + 20, not 120
    });
  });

  test('isPlayerATurn reflects whose turn it currently is', () {
    final match = TrainingMatch(
      initialProgressA: _allElementsUnlocked(),
      initialProgressB: _allElementsUnlocked(),
    );
    expect(match.isPlayerATurn, isTrue);

    match.playElementIds(['fire']);
    expect(match.isPlayerATurn, isFalse);

    match.playElementIds(['ice']);
    expect(match.isPlayerATurn, isTrue);
  });

  test('turnsPlayed counts successful plays regardless of damage', () {
    final match = TrainingMatch(
      initialProgressA: _allElementsUnlocked(),
      initialProgressB: _allElementsUnlocked(),
    );
    expect(match.turnsPlayed, 0);

    match.playElementIds(['fire']); // sem dano, ainda conta
    expect(match.turnsPlayed, 1);

    match.playElementIds(['wind']);
    expect(match.turnsPlayed, 2);
  });

  test('activeFieldEffectBadges resolves id and remainingTurns from a '
      'triggered combination', () {
    final match = TrainingMatch(
      initialApA: const ApPool(max: 5, current: 3),
      initialProgressA: _allElementsUnlocked(),
    );
    match.playElementIds(['fire', 'wind']); // Tempestade Ígnea

    expect(
      match.activeFieldEffectBadges,
      [const EffectBadgeView(id: 'ignited_storm', remainingTurns: null)],
    );
  });

  test('playerAActiveStatuses/playerBActiveStatuses resolve id and '
      'remainingTurns from an applied mutation status', () {
    final match = TrainingMatch(initialProgressA: _allElementsUnlocked());
    match.unlockSkillForCurrentPlayer('ember_mastery'); // Jogador A

    match.playElementIds(['fire']); // aplica Queimadura em Jogador B

    expect(match.playerAActiveStatuses, isEmpty);
    expect(
      match.playerBActiveStatuses,
      [const EffectBadgeView(id: 'burn', remainingTurns: 2)],
    );
  });

  test('a player seeded with Treino de Vitalidade already unlocked starts '
      'with 120 HP, not 100', () {
    final match = TrainingMatch(
      initialProgressA: SkillProgress(defaultSkillTree, unlockedNodeIds: ['vitality_training']),
    );

    expect(match.playerAMaxHp, equals(120));
    expect(match.playerACurrentHp, equals(120));
    expect(match.playerBMaxHp, equals(100));
  });

  test('a player seeded with Maestria da Brasa already unlocked applies '
      'Queimadura on the first action, no need to unlock again', () {
    final match = TrainingMatch(
      initialProgressA: SkillProgress(
        defaultSkillTree,
        unlockedNodeIds: ['ember_mastery', 'unlock_fire'],
      ),
    );

    match.playElementIds(['fire']);

    expect(match.lastAppliedStatusNames, contains('Queimadura'));
  });

  test('unlockedNodeIdsForPlayerA/B and discoveredCombinationIds reflect '
      'real state', () {
    final match = TrainingMatch(
      initialApA: const ApPool(max: 5, current: 3),
      initialProgressA: SkillProgress(
        defaultSkillTree,
        unlockedNodeIds: ['unlock_fire', 'unlock_wind'],
      ),
    );
    match.unlockSkillForCurrentPlayer('ember_mastery'); // Jogador A
    match.playElementIds(['fire', 'wind']); // Jogador A, Tempestade Ígnea

    expect(
      match.unlockedNodeIdsForPlayerA,
      ['unlock_fire', 'unlock_wind', 'ember_mastery'],
    );
    expect(match.unlockedNodeIdsForPlayerB, isEmpty);
    expect(match.discoveredCombinationIds, ['ignited_storm']);
  });

  group('fromPersistedProgress', () {
    test('seeds both players\' Skill Tree and the shared Discovery Book '
        'from raw ids', () {
      final match = TrainingMatch.fromPersistedProgress(
        unlockedNodeIdsA: ['ember_mastery'],
        unlockedNodeIdsB: ['vitality_training'],
        discoveredCombinationIds: ['ignited_storm'],
        turnsPlayedA: 0,
        turnsPlayedB: 0,
      );

      expect(match.unlockedNodeIdsForPlayerA, ['ember_mastery']);
      expect(match.unlockedNodeIdsForPlayerB, ['vitality_training']);
      expect(match.discoveredCombinationIds, ['ignited_storm']);
      expect(match.playerBMaxHp, equals(120)); // Vitalidade já aplicada
    });

    test('seeds the cumulative turns-played counters', () {
      final match = TrainingMatch.fromPersistedProgress(
        unlockedNodeIdsA: [],
        unlockedNodeIdsB: [],
        discoveredCombinationIds: [],
        turnsPlayedA: 7,
        turnsPlayedB: 12,
      );

      expect(match.cumulativeTurnsPlayedA, equals(7));
      expect(match.cumulativeTurnsPlayedB, equals(12));
    });
  });

  group('startNewBattleKeepingProgress', () {
    test('resets HP/turn/campo but keeps Skill Tree and Discovery Book', () {
      final match = TrainingMatch(
        initialApA: const ApPool(max: 5, current: 3),
        initialProgressA: _allElementsUnlocked(),
      );
      match.unlockSkillForCurrentPlayer('vitality_training'); // Jogador A
      match.playElementIds(['fire', 'wind']); // Jogador A, descobre Tempestade Ígnea

      final rematch = match.startNewBattleKeepingProgress();

      expect(rematch.playerAMaxHp, equals(120)); // Vitalidade mantida
      expect(rematch.playerACurrentHp, equals(120)); // batalha nova, HP cheio
      expect(rematch.currentTurnName, equals('Jogador A')); // turno resetado
      expect(rematch.activeFieldEffectNames, isEmpty); // campo resetado
      expect(rematch.discoveredCombinationIds, ['ignited_storm']); // mantido
    });

    test('keeps the cumulative turns-played counter (does not reset)', () {
      final match = TrainingMatch(initialProgressA: _allElementsUnlocked());
      match.playElementIds(['fire']); // Jogador A, 1 turno cumulativo

      final rematch = match.startNewBattleKeepingProgress();

      expect(rematch.cumulativeTurnsPlayedA, equals(1));
    });
  });

  test('playerAAp/playerAApMax/playerBAp/playerBApMax reflect real state',
      () {
    final match = TrainingMatch(initialProgressA: _allElementsUnlocked());
    expect(match.playerAAp, 0);
    expect(match.playerAApMax, 5);

    match.playElementIds(['fire']); // Jogador A regenera 1 AP no próprio turno

    expect(match.playerAAp, 1);
    expect(match.playerBAp, 0);
  });

  group('locked elements (Bloco 2b)', () {
    test('availableElementIdsForCurrentPlayer reflects granted elements', () {
      final match = TrainingMatch(
        initialProgressA: SkillProgress(
          defaultSkillTree,
          unlockedNodeIds: ['unlock_fire', 'unlock_wind'],
        ),
      );
      expect(
        match.availableElementIdsForCurrentPlayer,
        equals(['fire', 'wind']),
      );
    });

    test('playElementIds throws for an element the current player has not '
        'unlocked', () {
      final match = TrainingMatch(
        initialProgressA: SkillProgress(
          defaultSkillTree,
          unlockedNodeIds: ['unlock_fire'],
        ),
      );
      expect(
        () => match.playElementIds(['water']),
        throwsArgumentError,
      );
    });

    test('cumulativeTurnsPlayedA/B increment only for whoever just played', () {
      final match = TrainingMatch(
        initialProgressA: _allElementsUnlocked(),
        initialProgressB: _allElementsUnlocked(),
      );
      expect(match.cumulativeTurnsPlayedA, 0);
      expect(match.cumulativeTurnsPlayedB, 0);

      match.playElementIds(['fire']); // Jogador A
      expect(match.cumulativeTurnsPlayedA, 1);
      expect(match.cumulativeTurnsPlayedB, 0);

      match.playElementIds(['water']); // Jogador B
      expect(match.cumulativeTurnsPlayedA, 1);
      expect(match.cumulativeTurnsPlayedB, 1);
    });

    test('unlockSkillForCurrentPlayer throws for an element node without '
        'enough cumulative turns', () {
      final match = TrainingMatch(
        initialProgressA: SkillProgress(
          defaultSkillTree,
          unlockedNodeIds: ['unlock_fire', 'unlock_wind'],
        ),
      );
      expect(
        () => match.unlockSkillForCurrentPlayer('unlock_water'),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          'Faltam 10 turnos para desbloquear Água.',
        )),
      );
    });

    test('unlockSkillForCurrentPlayer unlocks an element node once enough '
        'cumulative turns have been played', () {
      final match = TrainingMatch(
        initialProgressA: SkillProgress(
          defaultSkillTree,
          unlockedNodeIds: ['unlock_fire', 'unlock_wind'],
        ),
        initialTurnsPlayedA: 10,
      );

      match.unlockSkillForCurrentPlayer('unlock_water');

      expect(match.availableElementIdsForCurrentPlayer, contains('water'));
    });

    test('turnsRemainingToUnlock reflects the increasing cost curve', () {
      final match = TrainingMatch(
        initialProgressA: SkillProgress(
          defaultSkillTree,
          unlockedNodeIds: ['unlock_fire', 'unlock_wind'],
        ),
        initialProgressB: SkillProgress(
          defaultSkillTree,
          unlockedNodeIds: ['unlock_fire'],
        ),
      );
      expect(match.turnsRemainingToUnlock('unlock_water'), equals(10));

      for (var i = 0; i < 10; i++) {
        match.playElementIds(['fire']); // Jogador A
        match.playElementIds(['fire']); // Jogador B
      }

      expect(match.turnsRemainingToUnlock('unlock_water'), isNull); // já alcançável
      match.unlockSkillForCurrentPlayer('unlock_water'); // ainda a vez de A
      expect(
        match.turnsRemainingToUnlock('unlock_earth'),
        equals(10), // 3 elementos já: (3-1)*10=20, já tem 10 jogados
      );
    });
  });
}
```

- [ ] **Step 2: Run tests to verify the expected failures**

Run: `cd app && flutter test test/game_domain/training_match_test.dart`
Expected: FAIL en masse — `initialProgressA`/`B` seeded with element-unlock ids reference `ElementUnlocks`/`unlock_fire` etc., and `availableElementIdsForCurrentPlayer`/`cumulativeTurnsPlayedA`/`B`/`turnsRemainingToUnlock` don't exist yet, and `fromPersistedProgress` doesn't accept `turnsPlayedA`/`B` yet. Confirm the failures are all about missing members/params, not typos in the test file itself.

- [ ] **Step 3: Rewrite `training_match.dart`**

Replace the full content of `app/lib/game_domain/training_match.dart` with:

```dart
import 'package:battle_engine/battle_engine.dart';

import 'effect_badge_view.dart';
import 'skill_tree_catalog.dart';

/// A local, offline 1v1 match where the same device controls both sides —
/// "Modo treino" (seção 12). No backend, no multiplayer, no AI opponent.
///
/// Each player has their own [SkillProgress] over `defaultSkillTree`: they
/// can unlock skill nodes on their turn, and every mutation/combination
/// modifier/HP bonus they've unlocked applies automatically — mutations
/// and combination modifiers to every action they take from then on (an
/// [Ability]/[Build] built fresh each turn from whatever elements they
/// picked + everything they've unlocked); a [MaxHpBonus] applies to their
/// HP immediately, live, since it doesn't wait for their next action. Two
/// players unlocking different nodes get different results from the same
/// elements — the promise from the design doc (seção 7), now playable.
///
/// Both players start at 100 HP (base) plus whatever [MaxHpBonus] they've
/// unlocked. A combination's damage always hits the opponent of whoever
/// played it; the match ends the moment either player's HP reaches 0.
///
/// Bloco 2b: each player can only play an element they've been granted
/// access to (see [SkillProgress.grantedElementIds]) — starts empty for a
/// bare [TrainingMatch]; real gameplay always goes through a one-time
/// starting-elements choice before the first match (`ElementStarterScreen`),
/// which seeds 2 elements directly into the persisted Skill Tree progress
/// the same way any other unlocked node is. Unlocking further "elementos"
/// branch nodes also requires enough cumulative turns played — see
/// [unlockSkillForCurrentPlayer].
///
/// Exposes only Flutter-friendly types, never a `battle_engine` type — ver
/// DECISION-011/017.
class TrainingMatch {
  static const _playerA = Combatant(id: 'a', name: 'Jogador A');
  static const _playerB = Combatant(id: 'b', name: 'Jogador B');
  static const _baseMaxHp = 100;

  final AbilityEngine _abilityEngine = AbilityEngine(
    TurnEngine(defaultCombinationBook),
  );

  late BattleState _state;
  late DiscoveryBook _discoveryBook;
  late SkillProgress _progressA;
  late SkillProgress _progressB;
  late int _cumulativeTurnsA;
  late int _cumulativeTurnsB;

  String? _lastTriggeredCombinationName;
  List<String> _lastAppliedStatusNames = [];
  int _turnsPlayed = 0;

  /// [initialProgressA]/[initialProgressB]/[initialDiscoveryBook] seedam
  /// uma partida já com progresso de uma partida anterior (Bloco 10 —
  /// persistência local do Modo Treino) — default vazio, mesmo
  /// comportamento de sempre quando não passados. O HP inicial já soma
  /// o bônus de qualquer `MaxHpBonus` que o progresso inicial conceda
  /// (ex: Treino de Vitalidade), não só quando desbloqueado ao vivo
  /// durante a partida. [initialApA]/[initialApB] existem só pra
  /// conveniência de teste (Bloco 2a) — nenhum código de produção
  /// precisa seedar AP, uma partida real sempre começa em 0.
  /// [initialTurnsPlayedA]/[initialTurnsPlayedB] seedam o contador
  /// cumulativo de turnos jogados (Bloco 2b — gate de desbloqueio de
  /// elementos), default 0.
  TrainingMatch({
    SkillProgress? initialProgressA,
    SkillProgress? initialProgressB,
    DiscoveryBook? initialDiscoveryBook,
    ApPool? initialApA,
    ApPool? initialApB,
    int initialTurnsPlayedA = 0,
    int initialTurnsPlayedB = 0,
  }) {
    _progressA = initialProgressA ?? SkillProgress(defaultSkillTree);
    _progressB = initialProgressB ?? SkillProgress(defaultSkillTree);
    _discoveryBook = initialDiscoveryBook ?? DiscoveryBook();
    _cumulativeTurnsA = initialTurnsPlayedA;
    _cumulativeTurnsB = initialTurnsPlayedB;
    _state = BattleState.start(
      playerA: _playerA,
      playerB: _playerB,
      playerAMaxHp: _baseMaxHp + _progressA.grantedMaxHpBonus,
      playerBMaxHp: _baseMaxHp + _progressB.grantedMaxHpBonus,
      ap: {
        _playerA: ?initialApA,
        _playerB: ?initialApB,
      },
    );
  }

  /// Monta uma partida a partir de progresso persistido em disco (ids
  /// crus, sem nenhum tipo do `battle_engine`) — usado por
  /// `TrainingScreen` ao abrir a tela, mantendo a regra de que a UI
  /// nunca precisa nomear um tipo do `battle_engine` (DECISION-011/017).
  factory TrainingMatch.fromPersistedProgress({
    required List<String> unlockedNodeIdsA,
    required List<String> unlockedNodeIdsB,
    required List<String> discoveredCombinationIds,
    required int turnsPlayedA,
    required int turnsPlayedB,
  }) {
    return TrainingMatch(
      initialProgressA: SkillProgress(defaultSkillTree, unlockedNodeIds: unlockedNodeIdsA),
      initialProgressB: SkillProgress(defaultSkillTree, unlockedNodeIds: unlockedNodeIdsB),
      initialDiscoveryBook: DiscoveryBook(discoveredCombinationIds: discoveredCombinationIds.toSet()),
      initialTurnsPlayedA: turnsPlayedA,
      initialTurnsPlayedB: turnsPlayedB,
    );
  }

  /// Começa uma batalha nova preservando Skill Tree/Descobertas/turnos
  /// cumulativos desta partida — usado por "Nova partida" (Bloco 10):
  /// reseta HP/turno/campo, mas não a progressão (o contador de turnos
  /// cumulativos do Bloco 2b segue a mesma regra).
  TrainingMatch startNewBattleKeepingProgress() {
    return TrainingMatch(
      initialProgressA: _progressA,
      initialProgressB: _progressB,
      initialDiscoveryBook: _discoveryBook,
      initialTurnsPlayedA: _cumulativeTurnsA,
      initialTurnsPlayedB: _cumulativeTurnsB,
    );
  }

  int get turnsPlayed => _turnsPlayed;

  String get currentTurnName => _state.currentTurn.name;

  List<String> get activeFieldEffectNames =>
      _state.activeFieldEffects.map((effect) => effect.name).toList();

  String? get lastTriggeredCombinationName => _lastTriggeredCombinationName;

  List<String> get lastAppliedStatusNames => _lastAppliedStatusNames;

  int get discoveredCount => _discoveryBook.discoveredCombinationIds.length;

  int get totalCombinationsCount => defaultCombinationBook.combinations.length;

  List<String> get playerAStatusNames =>
      _state.statusesOf(_playerA).map((s) => s.effect.name).toList();

  List<String> get playerBStatusNames =>
      _state.statusesOf(_playerB).map((s) => s.effect.name).toList();

  List<EffectBadgeView> get playerAActiveStatuses => _state
      .statusesOf(_playerA)
      .map((s) => EffectBadgeView(id: s.effect.id, remainingTurns: s.turnsRemaining))
      .toList();

  List<EffectBadgeView> get playerBActiveStatuses => _state
      .statusesOf(_playerB)
      .map((s) => EffectBadgeView(id: s.effect.id, remainingTurns: s.turnsRemaining))
      .toList();

  List<EffectBadgeView> get activeFieldEffectBadges => _state.activeFieldEffects
      .map((effect) => EffectBadgeView(id: effect.id, remainingTurns: effect.duration))
      .toList();

  List<String> get unlockedNodeIdsForPlayerA => _progressA.unlockedNodeIds;

  List<String> get unlockedNodeIdsForPlayerB => _progressB.unlockedNodeIds;

  List<String> get discoveredCombinationIds =>
      _discoveryBook.discoveredCombinationIds.toList();

  int get playerAAp => _state.apOf(_playerA).current;
  int get playerAApMax => _state.apOf(_playerA).max;
  int get playerBAp => _state.apOf(_playerB).current;
  int get playerBApMax => _state.apOf(_playerB).max;

  int get playerAMaxHp => _state.hpOf(_playerA).max;

  int get playerACurrentHp => _state.hpOf(_playerA).current;

  int get playerBMaxHp => _state.hpOf(_playerB).max;

  int get playerBCurrentHp => _state.hpOf(_playerB).current;

  /// Name of the winner, or null while the match is still ongoing.
  String? get winnerName => _state.winner?.name;

  bool get isOver => _state.winner != null;

  bool get _isPlayerATurn => _state.currentTurn == _playerA;

  /// Exposição pública de [_isPlayerATurn] — usada pela Game Presentation
  /// para saber de que lado é a vez, sem comparar `currentTurnName` por
  /// string.
  bool get isPlayerATurn => _isPlayerATurn;

  SkillProgress get _currentProgress =>
      _isPlayerATurn ? _progressA : _progressB;

  Combatant get _currentCombatant => _isPlayerATurn ? _playerA : _playerB;

  /// Skill nodes the player whose turn it currently is could unlock right
  /// now (prerequisites met, not yet unlocked).
  List<SkillNodeOption> get availableSkillNodesForCurrentPlayer =>
      _currentProgress.availableNodes.map(skillNodeOptionFrom).toList();

  /// Ids dos nós que o jogador da vez atual já desbloqueou — usado pela
  /// tela de Skill Tree visual (Bloco 7) pra saber o estado de cada nó da
  /// árvore inteira, não só os disponíveis agora.
  List<String> get unlockedNodeIdsForCurrentPlayer => _currentProgress.unlockedNodeIds;

  /// Names of the mutations/combination modifiers/HP bonuses the current
  /// player has already unlocked — shown so they can see their build
  /// taking shape.
  List<String> get unlockedGrantNamesForCurrentPlayer => [
        ..._currentProgress.grantedMutations.map((m) => m.name),
        ..._currentProgress.grantedCombinationModifiers.map((m) => m.name),
      ];

  /// Element ids the player whose turn it currently is can play with —
  /// used by the element picker to know which chips are selectable
  /// (Bloco 2b).
  List<String> get availableElementIdsForCurrentPlayer =>
      _currentProgress.grantedElementIds;

  /// Cumulative turns played by Jogador A/B, since ever — not reset by
  /// [startNewBattleKeepingProgress] (Bloco 2b's element-unlock gate).
  /// Direct per-player, not "of the current player": right after
  /// [playElementIds] passes the turn, "the current player" is already
  /// the opponent of whoever just played, so callers that need to save
  /// whoever just acted's counter need the specific player's value.
  int get cumulativeTurnsPlayedA => _cumulativeTurnsA;
  int get cumulativeTurnsPlayedB => _cumulativeTurnsB;

  /// Turns still needed before [nodeId] (an "elementos" branch node)
  /// becomes unlockable for whoever's turn it currently is — null if
  /// [nodeId] doesn't grant an [ElementUnlock], is already unlocked, or
  /// the requirement is already met.
  int? turnsRemainingToUnlock(String nodeId) {
    final grant = defaultSkillTree.nodeById(nodeId)?.grants;
    if (grant is! ElementUnlock) return null;
    if (_currentProgress.isUnlocked(nodeId)) return null;
    final requiredTurns = (_currentProgress.grantedElementIds.length - 1) * 10;
    final cumulativeTurns = _isPlayerATurn ? _cumulativeTurnsA : _cumulativeTurnsB;
    final remaining = requiredTurns - cumulativeTurns;
    return remaining > 0 ? remaining : null;
  }

  /// Unlocks [nodeId] for whoever's turn it currently is. If the node
  /// grants a [MaxHpBonus], it's applied to that player's HP immediately
  /// (not deferred to their next action). Throws `StateError` if it can't
  /// be unlocked yet (see `SkillProgress.unlock`) — or, for an
  /// [ElementUnlock] node (Bloco 2b), if that player hasn't played enough
  /// cumulative turns yet (`(E-1) × 10`, `E` = how many elements they
  /// already have, including the 2 starting ones).
  void unlockSkillForCurrentPlayer(String nodeId) {
    final actor = _currentCombatant;
    final node = defaultSkillTree.nodeById(nodeId);
    final grant = node?.grants;
    if (grant is ElementUnlock && !_currentProgress.isUnlocked(nodeId)) {
      final requiredTurns = (_currentProgress.grantedElementIds.length - 1) * 10;
      final cumulativeTurns = _isPlayerATurn ? _cumulativeTurnsA : _cumulativeTurnsB;
      if (cumulativeTurns < requiredTurns) {
        throw StateError(
          'Faltam ${requiredTurns - cumulativeTurns} turnos para '
          'desbloquear ${node!.name}.',
        );
      }
    }

    final updated = _currentProgress.unlock(nodeId);
    if (_isPlayerATurn) {
      _progressA = updated;
    } else {
      _progressB = updated;
    }

    if (grant is MaxHpBonus) {
      _state = _state.withMaxHpIncreased(actor, grant.bonus);
    }
  }

  /// Plays the elements identified by [elementIds] (1 a 3) for whoever's
  /// turn it currently is, building an [Ability] on the fly from those
  /// elements plus everything the player has unlocked, wrapped in a
  /// [Build] (validated — always valid here, since mutations/modifiers
  /// come straight from what's granted). Throws `ArgumentError` for an
  /// unknown element id, or for one the current player hasn't unlocked
  /// yet (Bloco 2b — `availableElementIdsForCurrentPlayer`; the UI never
  /// offers a locked element as selectable, this closes the guarantee).
  /// Throws `StateError` if the match is already over, or (from
  /// `TurnEngine`) if there isn't enough AP for the combination attempted
  /// (Bloco 2a).
  void playElementIds(List<String> elementIds) {
    final wasPlayerATurn = _isPlayerATurn;
    final elements = elementIds
        .map(
          (id) => Elements.all.firstWhere(
            (element) => element.id == id,
            orElse: () =>
                throw ArgumentError.value(id, 'elementIds', 'unknown element'),
          ),
        )
        .toList();

    final progress = _currentProgress;
    for (final id in elementIds) {
      if (!progress.grantedElementIds.contains(id)) {
        throw ArgumentError.value(id, 'elementIds', 'element not unlocked yet');
      }
    }

    final ability = Ability(
      id: 'turn_action',
      name: 'Ação',
      baseElements: elements,
      mutations: progress.grantedMutations,
    );
    final build = Build(
      id: 'training_build',
      name: 'Build de Treino',
      skillProgress: progress,
      abilities: [ability],
      combinationModifiers: progress.grantedCombinationModifiers,
    );

    final result = _abilityEngine.useAbility(
      _state,
      _state.currentTurn,
      build.abilityById('turn_action')!,
      combinationModifiers: build.combinationModifiers,
    );

    _state = result.state;
    _lastTriggeredCombinationName = result.triggeredCombination?.resultName;
    _lastAppliedStatusNames = result.effect.statusesToApply
        .map((targeted) => targeted.status.effect.name)
        .toList();
    if (result.triggeredCombination != null) {
      _discoveryBook = _discoveryBook.withDiscovered(
        result.triggeredCombination!,
      );
    }
    _turnsPlayed++;
    if (wasPlayerATurn) {
      _cumulativeTurnsA++;
    } else {
      _cumulativeTurnsB++;
    }
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd app && flutter test test/game_domain/training_match_test.dart`
Expected: PASS (every test in the file, including the new `group('locked elements (Bloco 2b)', ...)`).

- [ ] **Step 5: Run the whole app suite to check for further ripple**

Run: `cd app && flutter test`
Expected: failures confined to `test/training_screen_test.dart` and possibly `test/game_domain/skill_tree_catalog_test.dart`/`test/skill_tree_screen_test.dart` — every other test file (including `multiplayer_match_test.dart`, `battle_scene_view_test.dart`, `battle_hud_widget_test.dart`) should be unaffected, since Bloco 2b never touches Multiplayer or presentation types. Tasks 6-8 fix the remaining files; do not attempt to fix `training_screen_test.dart`/`skill_tree_catalog_test.dart`/`skill_tree_screen_test.dart` here.

- [ ] **Step 6: Commit**

```bash
git add app/lib/game_domain/training_match.dart app/test/game_domain/training_match_test.dart
git commit -m "$(cat <<'EOF'
TrainingMatch ganha gate de elementos bloqueados (Bloco 2b)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: `ElementStarterScreen` (tela de escolha inicial)

**Files:**
- Create: `app/lib/ui/element_starter_screen.dart`
- Create: `app/test/element_starter_screen_test.dart`

**Interfaces:**
- Consumes: `ElementCatalog`/`ElementOption` (`app/lib/game_domain/element_catalog.dart`, already exists); presentation widgets `ArenaBackdropPainter`, `PixelContentPanel`, `PixelElementChip`, `PixelMenuButton`, `PixelOutlinedText` (all already exist).
- Produces: `ElementStarterScreen({required String playerLabel, required ValueChanged<List<String>> onConfirm})`.

- [ ] **Step 1: Write the failing test**

Create `app/test/element_starter_screen_test.dart`:

```dart
import 'package:app/ui/element_starter_screen.dart';
import 'package:app/game_presentation/pixel_menu_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the player label in the title', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ElementStarterScreen(
        playerLabel: 'Jogador A',
        onConfirm: (_) {},
      ),
    ));
    await tester.pump();

    expect(find.textContaining('Jogador A'), findsWidgets);
  });

  testWidgets('Confirmar is disabled with 0 or 1 elements selected, '
      'enabled with exactly 2', (tester) async {
    List<String>? confirmed;
    await tester.pumpWidget(MaterialApp(
      home: ElementStarterScreen(
        playerLabel: 'Jogador A',
        onConfirm: (ids) => confirmed = ids,
      ),
    ));
    await tester.pump();

    var button = tester.widget<PixelMenuButton>(
      find.widgetWithText(PixelMenuButton, 'Confirmar'),
    );
    expect(button.onPressed, isNull);

    await tester.tap(find.text('🔥 Fogo'));
    await tester.pump();

    button = tester.widget<PixelMenuButton>(
      find.widgetWithText(PixelMenuButton, 'Confirmar'),
    );
    expect(button.onPressed, isNull);

    await tester.tap(find.text('🌪️ Vento'));
    await tester.pump();

    button = tester.widget<PixelMenuButton>(
      find.widgetWithText(PixelMenuButton, 'Confirmar'),
    );
    expect(button.onPressed, isNotNull);

    await tester.tap(find.text('Confirmar'));
    await tester.pump();

    expect(confirmed, equals(['fire', 'wind']));
  });

  testWidgets('selecting a 3rd element does not replace the first 2',
      (tester) async {
    List<String>? confirmed;
    await tester.pumpWidget(MaterialApp(
      home: ElementStarterScreen(
        playerLabel: 'Jogador A',
        onConfirm: (ids) => confirmed = ids,
      ),
    ));
    await tester.pump();

    await tester.tap(find.text('🔥 Fogo'));
    await tester.pump();
    await tester.tap(find.text('🌪️ Vento'));
    await tester.pump();
    await tester.tap(find.text('💧 Água'));
    await tester.pump();

    await tester.tap(find.text('Confirmar'));
    await tester.pump();

    expect(confirmed, equals(['fire', 'wind']));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/element_starter_screen_test.dart`
Expected: FAIL — `element_starter_screen.dart` doesn't exist yet.

- [ ] **Step 3: Implement `ElementStarterScreen`**

Create `app/lib/ui/element_starter_screen.dart`:

```dart
import 'package:flutter/material.dart';

import '../game_domain/element_catalog.dart';
import '../game_presentation/pixel_arena_background.dart';
import '../game_presentation/pixel_content_panel.dart';
import '../game_presentation/pixel_element_chip.dart';
import '../game_presentation/pixel_menu_button.dart';
import '../game_presentation/pixel_outlined_text.dart';

/// Tela cheia e bloqueante (mesmo padrão do `UpdateGateScreen`, só que
/// local ao Modo Treino): escolhe os 2 elementos iniciais de um jogador,
/// uma vez só (Bloco 2b, DECISION-047). Os outros 8 elementos começam
/// bloqueados e se desbloqueiam depois via Skill Tree. `TrainingScreen`
/// decide quando mostrar isso (uma vez por slot `'a'`/`'b'`) e o que
/// fazer com os 2 ids escolhidos — esta tela só coleta a escolha.
class ElementStarterScreen extends StatefulWidget {
  const ElementStarterScreen({
    super.key,
    required this.playerLabel,
    required this.onConfirm,
  });

  final String playerLabel;
  final ValueChanged<List<String>> onConfirm;

  @override
  State<ElementStarterScreen> createState() => _ElementStarterScreenState();
}

class _ElementStarterScreenState extends State<ElementStarterScreen> {
  final Set<String> _selectedIds = {};

  void _toggle(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else if (_selectedIds.length < 2) {
        _selectedIds.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final elements = const ElementCatalog().all();

    return Stack(
      children: [
        Positioned.fill(child: CustomPaint(painter: ArenaBackdropPainter())),
        Scaffold(
          backgroundColor: Colors.transparent,
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: PixelContentPanel(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PixelOutlinedText(
                    'Escolha 2 elementos iniciais — ${widget.playerLabel}',
                    fontSize: 18,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final element in elements)
                        PixelElementChip(
                          label: '${element.symbol} ${element.name}',
                          selected: _selectedIds.contains(element.id),
                          onTap: () => _toggle(element.id),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  PixelMenuButton(
                    label: 'Confirmar',
                    onPressed: _selectedIds.length == 2
                        ? () => widget.onConfirm(_selectedIds.toList())
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/element_starter_screen_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add app/lib/ui/element_starter_screen.dart app/test/element_starter_screen_test.dart
git commit -m "$(cat <<'EOF'
Adiciona ElementStarterScreen — escolha inicial de elementos (Bloco 2b)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: `SkillTreeScreen` ganha `extraLockedHint` + ícones/nome da branch "elementos"

**Files:**
- Modify: `app/lib/ui/skill_tree_screen.dart`
- Modify: `app/lib/game_domain/skill_tree_catalog.dart`
- Modify: `app/test/skill_tree_screen_test.dart`
- Modify: `app/test/game_domain/skill_tree_catalog_test.dart`

**Interfaces:**
- Produces: `SkillTreeScreen`'s new optional `final String? Function(String nodeId)? extraLockedHint` param.

- [ ] **Step 1: Fix the now-failing `hasLength(8)` assertion and add branch coverage**

In `app/test/game_domain/skill_tree_catalog_test.dart`, `defaultSkillTree` now has 18 nodes (8 original + 10 "elementos") because of Task 2 — replace the `allSkillTreeNodes` group's test:

```dart
  group('allSkillTreeNodes', () {
    test('returns all 18 nodes from defaultSkillTree with icons and prerequisites', () {
      final nodes = allSkillTreeNodes();

      expect(nodes, hasLength(18));

      final ember = nodes.firstWhere((n) => n.id == 'ember_mastery');
      expect(ember.name, 'Maestria da Brasa');
      expect(ember.branch, 'fogo');
      expect(ember.icon, '🔥');
      expect(ember.prerequisites, isEmpty);

      final wildfire = nodes.firstWhere((n) => n.id == 'wildfire_path');
      expect(wildfire.prerequisites, ['ember_mastery']);
      expect(wildfire.icon, '🌋');

      final unlockFire = nodes.firstWhere((n) => n.id == 'unlock_fire');
      expect(unlockFire.branch, 'elementos');
      expect(unlockFire.icon, '🔥');
      expect(unlockFire.prerequisites, isEmpty);
    });
  });
```

Add a branch-name assertion to the existing `skillTreeBranchDisplayName` group — replace it with:

```dart
  group('skillTreeBranchDisplayName', () {
    test('returns the known display names', () {
      expect(skillTreeBranchDisplayName('fogo'), 'Fogo');
      expect(skillTreeBranchDisplayName('precisao'), 'Precisão');
      expect(skillTreeBranchDisplayName('elemental'), 'Elemental');
      expect(skillTreeBranchDisplayName('vitalidade'), 'Vitalidade');
      expect(skillTreeBranchDisplayName('defesa'), 'Defesa');
      expect(skillTreeBranchDisplayName('elementos'), 'Elementos');
    });

    test('falls back to the raw branch string when unknown', () {
      expect(skillTreeBranchDisplayName('mystery'), 'mystery');
    });
  });
```

- [ ] **Step 2: Run test to verify the expected failures**

Run: `cd app && flutter test test/game_domain/skill_tree_catalog_test.dart`
Expected: FAIL — `hasLength(18)` fails against the still-unmodified `_skillTreeNodeIcons`/`_skillTreeBranchDisplayNames` maps (the 10 new nodes fall back to `'❔'`, and `'elementos'` falls back to the raw string).

- [ ] **Step 3: Add icons and the branch display name**

In `app/lib/game_domain/skill_tree_catalog.dart`, replace `_skillTreeNodeIcons` with:

```dart
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
```

Replace `_skillTreeBranchDisplayNames` with:

```dart
const _skillTreeBranchDisplayNames = {
  'fogo': 'Fogo',
  'precisao': 'Precisão',
  'elemental': 'Elemental',
  'vitalidade': 'Vitalidade',
  'defesa': 'Defesa',
  'elementos': 'Elementos',
};
```

(Nothing else in the file changes — `SkillNodeOption`, `skillNodeOptionFrom`, `availableSkillNodeOptions`, `allSkillTreeNodes`, `skillTreeBranchDisplayName` all stay exactly as they are.)

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/game_domain/skill_tree_catalog_test.dart`
Expected: PASS (all tests in the file).

- [ ] **Step 5: Write the failing test for `extraLockedHint`**

In `app/test/skill_tree_screen_test.dart`, add a new test at the end of `main()`, right before the closing `}`:

```dart
  testWidgets(
      'shows the extraLockedHint text instead of the button when the node '
      'is available but the hint is non-null', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SkillTreeScreen(
        title: 'Habilidades',
        unlockedNodeIds: const [],
        canUnlockNow: true,
        extraLockedHint: (nodeId) =>
            nodeId == 'ember_mastery' ? 'Faltam 7 turnos.' : null,
        onUnlock: (_) async => throw StateError('should not be called'),
      ),
    ));
    await tester.pump();

    await tester.tap(find.text('Maestria da Brasa'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Faltam 7 turnos.'), findsOneWidget);
    expect(find.text('Desbloquear'), findsNothing);
  });
```

- [ ] **Step 6: Run test to verify it fails**

Run: `cd app && flutter test test/skill_tree_screen_test.dart`
Expected: FAIL — `extraLockedHint` isn't a recognized constructor parameter yet.

- [ ] **Step 7: Implement `extraLockedHint`**

In `app/lib/ui/skill_tree_screen.dart`, change the constructor and field list:

```dart
class SkillTreeScreen extends StatefulWidget {
  const SkillTreeScreen({
    super.key,
    required this.title,
    required this.unlockedNodeIds,
    required this.canUnlockNow,
    required this.onUnlock,
    this.extraLockedHint,
  });

  final String title;
  final List<String> unlockedNodeIds;
  final bool canUnlockNow;
  final Future<String?> Function(String nodeId) onUnlock;
  final String? Function(String nodeId)? extraLockedHint;
```

Change `_openNodeDetail` to compute and use the hint — replace:

```dart
  void _openNodeDetail(SkillTreeNodeOption node) {
    final state = skillTreeNodeState(node, _unlockedNodeIds);
    showModalBottomSheet<void>(
```

with:

```dart
  void _openNodeDetail(SkillTreeNodeOption node) {
    final state = skillTreeNodeState(node, _unlockedNodeIds);
    final hint = state == SkillTreeNodeState.available
        ? widget.extraLockedHint?.call(node.id)
        : null;
    showModalBottomSheet<void>(
```

And replace the `if`/`else if` chain inside the sheet's `Column` children:

```dart
              if (state == SkillTreeNodeState.locked)
                Text('Requer: ${_prerequisiteNames(node)}')
              else if (state == SkillTreeNodeState.available && !widget.canUnlockNow)
                const Text('Só dá pra desbloquear na sua vez.')
              else if (state == SkillTreeNodeState.available)
```

with:

```dart
              if (state == SkillTreeNodeState.locked)
                Text('Requer: ${_prerequisiteNames(node)}')
              else if (state == SkillTreeNodeState.available && hint != null)
                Text(hint)
              else if (state == SkillTreeNodeState.available && !widget.canUnlockNow)
                const Text('Só dá pra desbloquear na sua vez.')
              else if (state == SkillTreeNodeState.available)
```

(The `PixelMenuButton`/`onPressed` branch right after stays exactly as it is — this only inserts one new branch before the existing "not your turn" one.)

- [ ] **Step 8: Run tests to verify they pass**

Run: `cd app && flutter test test/skill_tree_screen_test.dart`
Expected: PASS (all 4 tests in the file — the 3 pre-existing ones are unaffected since `extraLockedHint` defaults to `null`).

- [ ] **Step 9: Run the whole app suite to confirm `multiplayer_battle_screen.dart` is unaffected**

Run: `cd app && flutter test`
Expected: `multiplayer_battle_screen_test.dart` and every Multiplayer-related test file still PASS unchanged (the new param is optional and `multiplayer_battle_screen.dart` never passes it, so `extraLockedHint` stays `null` there — identical behavior to before). `training_screen_test.dart` failures are still expected and unrelated to this task — Task 8 fixes them.

- [ ] **Step 10: Commit**

```bash
git add app/lib/ui/skill_tree_screen.dart app/lib/game_domain/skill_tree_catalog.dart app/test/skill_tree_screen_test.dart app/test/game_domain/skill_tree_catalog_test.dart
git commit -m "$(cat <<'EOF'
SkillTreeScreen ganha extraLockedHint; ícones da branch elementos (Bloco 2b)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 8: Fiação na `TrainingScreen`

**Files:**
- Modify: `app/lib/ui/training_screen.dart`
- Modify: `app/test/training_screen_test.dart`

**Interfaces:**
- Consumes: `ElementStarterScreen` (Task 6), `SkillTreeScreen.extraLockedHint` (Task 7), `TrainingMatch.availableElementIdsForCurrentPlayer`/`cumulativeTurnsPlayedA`/`B`/`turnsRemainingToUnlock`/`fromPersistedProgress` with `turnsPlayedA`/`B` (Task 5), `TrainingProgressStore.loadTurnsPlayed`/`saveTurnsPlayed` (Task 4).

This task never imports `package:battle_engine/battle_engine.dart` (DECISION-011/017) — the "has this player picked their starting elements yet" check and the "which skill node id does this element unlock" mapping both use the `'unlock_<elementId>'` string convention directly, not `ElementUnlocks`.

- [ ] **Step 1: Rewrite `training_screen_test.dart` in full**

Replace the full content of `app/test/training_screen_test.dart` with:

```dart
import 'package:app/game_domain/training_match.dart';
import 'package:app/game_presentation/pixel_menu_button.dart';
import 'package:app/main.dart';
import 'package:app/ui/training_screen.dart';
import 'package:battle_engine/battle_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

SkillProgress _allElementsUnlocked() => SkillProgress(
      defaultSkillTree,
      unlockedNodeIds: ElementUnlocks.all.map((u) => u.id).toList(),
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'selecting fire and wind then playing triggers Tempestade Ígnea and '
    'passes the turn to Jogador B',
    (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: TrainingScreen(
          initialMatch: TrainingMatch(
            initialApA: const ApPool(max: 5, current: 3),
            initialProgressA: _allElementsUnlocked(),
          ),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Vez de: Jogador A'), findsOneWidget);

      await tester.tap(find.text('Escolher elementos'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('🔥 Fogo'));
      await tester.pump();
      await tester.tap(find.text('🌪️ Vento'));
      await tester.pump();

      await tester.tap(find.text('Confirmar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.ensureVisible(find.text('Jogar'));
      await tester.tap(find.text('Jogar'));
      await tester.pump();

      expect(find.text('Vez de: Jogador B'), findsOneWidget);
      expect(
        find.text('Última combinação: Tempestade Ígnea'),
        findsOneWidget,
      );
      expect(find.text('Descobertas: 1/3'), findsOneWidget);
      expect(find.textContaining('80/100 HP'), findsOneWidget);
    },
  );

  testWidgets('the play button is disabled until an element is selected',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'training_unlocked_a': ['unlock_fire'],
      'training_unlocked_b': ['unlock_fire'],
    });

    await tester.pumpWidget(const GameApp());
    await tester.pump(const Duration(milliseconds: 1)); // resolve o Future.delayed da checagem de atualização

    await tester.tap(find.text('MODO TREINO'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final button = tester.widget<PixelMenuButton>(
      find.widgetWithText(PixelMenuButton, 'Jogar'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets(
    'unlocking Maestria da Brasa applies Queimadura to the opponent on the '
    'next action',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'training_unlocked_a': ['unlock_fire'],
        'training_unlocked_b': ['unlock_fire'],
      });

      await tester.pumpWidget(const GameApp());
      await tester.pump(const Duration(milliseconds: 1)); // resolve o Future.delayed da checagem de atualização

      await tester.tap(find.text('MODO TREINO'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('🔥 Fogo'));
      await tester.pump();

      await tester.tap(find.text('Confirmar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.ensureVisible(find.text('Jogar'));
      await tester.tap(find.text('Jogar'));
      await tester.pump();

      expect(
        find.text('Efeitos aplicados: Queimadura'),
        findsOneWidget,
      );
      expect(find.text('🔥'), findsOneWidget); // badge de Queimadura em Jogador B
    },
  );

  testWidgets(
    'shows the winner and a rematch button once the battle ends, hiding '
    'the play form',
    (WidgetTester tester) async {
      final match = TrainingMatch(
        initialProgressA: SkillProgress(defaultSkillTree, unlockedNodeIds: ['unlock_fire']),
        initialProgressB: SkillProgress(defaultSkillTree, unlockedNodeIds: ['unlock_ice']),
      );
      // 5 basic damage per hit (single element, always free) — 20 hits
      // defeat 100 HP.
      for (var i = 0; i < 19; i++) {
        match.playElementIds(['fire']); // Jogador A
        match.playElementIds(['ice']); // Jogador B
      }
      match.playElementIds(['fire']); // 20th hit: defeats Jogador B
      expect(match.isOver, isTrue); // sanity check on the setup itself

      await tester.pumpWidget(
        MaterialApp(home: TrainingScreen(initialMatch: match)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.textContaining('Vencedor: Jogador A'), findsOneWidget);
      expect(find.text('Nova partida'), findsOneWidget);
      expect(find.text('Jogar'), findsNothing);
    },
  );

  testWidgets('Nova partida starts a fresh match', (WidgetTester tester) async {
    final match = TrainingMatch(
      initialProgressA: SkillProgress(defaultSkillTree, unlockedNodeIds: ['unlock_fire']),
      initialProgressB: SkillProgress(defaultSkillTree, unlockedNodeIds: ['unlock_ice']),
    );
    for (var i = 0; i < 19; i++) {
      match.playElementIds(['fire']);
      match.playElementIds(['ice']);
    }
    match.playElementIds(['fire']);

    await tester.pumpWidget(
      MaterialApp(home: TrainingScreen(initialMatch: match)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.ensureVisible(find.text('Nova partida'));
    await tester.tap(find.text('Nova partida'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Vez de: Jogador A'), findsOneWidget);
    expect(find.text('Jogar'), findsOneWidget);
  });

  testWidgets(
    'loads persisted Skill Tree progress before showing the play form',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'training_unlocked_a': ['ember_mastery', 'unlock_fire'],
        'training_unlocked_b': ['unlock_fire'],
      });

      await tester.pumpWidget(const MaterialApp(home: TrainingScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));

      await tester.tap(find.byIcon(Icons.auto_awesome));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('Caminho do Incêndio'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Desbloquear'), findsOneWidget);
    },
  );

  testWidgets(
    'shows a friendly message when a combo is attempted without enough AP',
    (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: TrainingScreen(
          initialMatch: TrainingMatch(
            initialProgressA: SkillProgress(
              defaultSkillTree,
              unlockedNodeIds: ['unlock_fire', 'unlock_wind'],
            ),
          ), // AP começa em 0
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('Escolher elementos'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('🔥 Fogo'));
      await tester.pump();
      await tester.tap(find.text('🌪️ Vento'));
      await tester.pump();

      await tester.tap(find.text('Confirmar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.ensureVisible(find.text('Jogar'));
      await tester.tap(find.text('Jogar'));
      await tester.pump();

      expect(find.text('AP insuficiente para essa combinação.'), findsOneWidget);
      expect(find.text('Vez de: Jogador A'), findsOneWidget); // turno não passou
    },
  );

  testWidgets(
    'shows the starting-element picker for Jogador A when no progress is '
    'saved yet, then for Jogador B, then the normal play form',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: TrainingScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));

      expect(find.textContaining('Jogador A'), findsWidgets);

      await tester.tap(find.text('🔥 Fogo'));
      await tester.pump();
      await tester.tap(find.text('🌪️ Vento'));
      await tester.pump();
      await tester.tap(find.text('Confirmar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.textContaining('Jogador B'), findsWidgets);

      await tester.tap(find.text('🔥 Fogo'));
      await tester.pump();
      await tester.tap(find.text('🌪️ Vento'));
      await tester.pump();
      await tester.tap(find.text('Confirmar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Vez de: Jogador A'), findsOneWidget);
    },
  );

  testWidgets('locked elements appear with a lock icon and are not '
      'selectable', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: TrainingScreen(
        initialMatch: TrainingMatch(
          initialProgressA: SkillProgress(
            defaultSkillTree,
            unlockedNodeIds: ['unlock_fire'],
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Escolher elementos'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('🔥 Fogo'), findsOneWidget);
    expect(find.text('🔒 Água'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run tests to verify the expected failures**

Run: `cd app && flutter test test/training_screen_test.dart`
Expected: most tests FAIL — the two new tests fail because onboarding/lock-icon behavior doesn't exist yet; several existing tests fail because `TrainingMatch.fromPersistedProgress` doesn't get called with `turnsPlayedA`/`B` (it's called internally by `TrainingScreen`, not by the test, so this manifests as the app hanging on the loading spinner or throwing — confirm the failures point at `training_screen.dart`, not the test file itself).

- [ ] **Step 3: Wire up `training_screen.dart`**

Replace the full content of `app/lib/ui/training_screen.dart` with:

```dart
import 'dart:async';

import 'package:flutter/material.dart';

import '../game_domain/attack_event.dart';
import '../game_domain/battle_scene_view.dart';
import '../game_domain/element_catalog.dart';
import '../game_domain/training_match.dart';
import '../game_domain/training_progress_store.dart';
import '../game_presentation/battle_scene_widget.dart';
import '../game_presentation/pixel_arena_background.dart';
import '../game_presentation/pixel_content_panel.dart';
import '../game_presentation/pixel_element_chip.dart';
import '../game_presentation/pixel_menu_button.dart';
import '../game_presentation/pixel_outlined_text.dart';
import '../game_presentation/pixel_page_route.dart';
import '../game_presentation/pixel_sheet_panel.dart';
import '../game_presentation/sfx_player.dart';
import 'element_starter_screen.dart';
import 'skill_tree_screen.dart';

/// Modo treino: batalha local, offline, hotseat — os dois lados jogados no
/// mesmo aparelho. Sem backend, sem multiplayer, sem IA. Cada jogador pode
/// desbloquear habilidades da Skill Tree na própria vez; o que já
/// desbloqueou se aplica automaticamente em toda ação que jogar depois (e,
/// no caso de bônus de HP, imediatamente). A partida termina quando o HP
/// de alguém chega a 0.
///
/// Bloco 2b: antes da primeira partida, cada jogador (Jogador A, depois
/// Jogador B) escolhe 2 elementos iniciais via [ElementStarterScreen] —
/// só acontece uma vez por slot, nunca de novo depois de salvo.
class TrainingScreen extends StatefulWidget {
  const TrainingScreen({super.key, TrainingMatch? initialMatch})
      : _initialMatch = initialMatch;

  final TrainingMatch? _initialMatch;

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  final TrainingProgressStore _progressStore = TrainingProgressStore();
  late TrainingMatch _match;
  bool _loading = true;
  String? _pendingOnboardingSlot;
  List<String> _unlockedA = [];
  List<String> _unlockedB = [];
  List<String> _discovered = [];
  int _turnsPlayedA = 0;
  int _turnsPlayedB = 0;
  final Set<String> _selectedIds = {};
  String? _error;
  AttackEvent? _pendingAttack;

  @override
  void initState() {
    super.initState();
    final initial = widget._initialMatch;
    if (initial != null) {
      _match = initial;
      _loading = false;
    } else {
      unawaited(_loadPersistedMatch());
    }
  }

  /// Todo nó da branch "elementos" tem id `'unlock_<elementId>'` (ver
  /// `ElementUnlocks` em `battle_engine`) — checar o prefixo evita a UI
  /// precisar importar aquele tipo (DECISION-011/017).
  bool _hasChosenStartingElements(List<String> unlockedNodeIds) {
    return unlockedNodeIds.any((id) => id.startsWith('unlock_'));
  }

  Future<void> _loadPersistedMatch() async {
    _unlockedA = await _progressStore.loadUnlockedNodeIds('a');
    _unlockedB = await _progressStore.loadUnlockedNodeIds('b');
    _discovered = await _progressStore.loadDiscoveredCombinationIds();
    _turnsPlayedA = await _progressStore.loadTurnsPlayed('a');
    _turnsPlayedB = await _progressStore.loadTurnsPlayed('b');
    if (!mounted) return;
    if (!_hasChosenStartingElements(_unlockedA)) {
      setState(() {
        _pendingOnboardingSlot = 'a';
        _loading = false;
      });
      return;
    }
    if (!_hasChosenStartingElements(_unlockedB)) {
      setState(() {
        _pendingOnboardingSlot = 'b';
        _loading = false;
      });
      return;
    }
    _buildMatchFromLoadedProgress();
  }

  void _buildMatchFromLoadedProgress() {
    setState(() {
      _match = TrainingMatch.fromPersistedProgress(
        unlockedNodeIdsA: _unlockedA,
        unlockedNodeIdsB: _unlockedB,
        discoveredCombinationIds: _discovered,
        turnsPlayedA: _turnsPlayedA,
        turnsPlayedB: _turnsPlayedB,
      );
      _pendingOnboardingSlot = null;
      _loading = false;
    });
  }

  Future<void> _confirmStartingElements(List<String> elementIds) async {
    final slot = _pendingOnboardingSlot!;
    final nodeIds = elementIds.map((id) => 'unlock_$id').toList();
    if (slot == 'a') {
      _unlockedA = [..._unlockedA, ...nodeIds];
      await _progressStore.saveUnlockedNodeIds('a', _unlockedA);
      if (!mounted) return;
      if (!_hasChosenStartingElements(_unlockedB)) {
        setState(() => _pendingOnboardingSlot = 'b');
        return;
      }
    } else {
      _unlockedB = [..._unlockedB, ...nodeIds];
      await _progressStore.saveUnlockedNodeIds('b', _unlockedB);
      if (!mounted) return;
    }
    _buildMatchFromLoadedProgress();
  }

  void _toggleElement(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else if (_selectedIds.length < 3) {
        _selectedIds.add(id);
      }
    });
  }

  void _playTurn() {
    setState(() {
      _error = null;
      final playedElementIds = _selectedIds.toList();
      final wasPlayerATurn = _match.isPlayerATurn;
      final hpABefore = _match.playerACurrentHp;
      final hpBBefore = _match.playerBCurrentHp;
      final discoveredCountBefore = _match.discoveredCombinationIds.length;
      try {
        _match.playElementIds(playedElementIds);
        _selectedIds.clear();

        final triggered = _match.lastTriggeredCombinationName != null;
        final appliedStatus = _match.lastAppliedStatusNames;
        if (triggered || appliedStatus.isNotEmpty) {
          final damage = wasPlayerATurn
              ? hpBBefore - _match.playerBCurrentHp
              : hpABefore - _match.playerACurrentHp;
          _pendingAttack = AttackEvent(
            sequenceId: _match.turnsPlayed,
            attackerIsLeft: wasPlayerATurn,
            elementIds: playedElementIds,
            comboName: _match.lastTriggeredCombinationName,
            damage: damage,
            appliedStatusNames: appliedStatus,
          );
        }
        if (_match.discoveredCombinationIds.length != discoveredCountBefore) {
          unawaited(
            _progressStore.saveDiscoveredCombinationIds(_match.discoveredCombinationIds),
          );
        }
        if (wasPlayerATurn) {
          unawaited(_progressStore.saveTurnsPlayed('a', _match.cumulativeTurnsPlayedA));
        } else {
          unawaited(_progressStore.saveTurnsPlayed('b', _match.cumulativeTurnsPlayedB));
        }
        if (_match.isOver) {
          sfxPlayer.play(SfxId.victory);
        }
      } on ArgumentError {
        _error = 'Jogada inválida.';
      } on StateError {
        _error = 'AP insuficiente para essa combinação.';
      }
    });
  }

  void _startNewMatch() {
    setState(() {
      _match = _match.startNewBattleKeepingProgress();
      _selectedIds.clear();
      _error = null;
    });
  }

  Future<void> _openSkillTree() async {
    await Navigator.of(context).push(pixelSlideRoute((_) => SkillTreeScreen(
      title: 'Habilidades de ${_match.currentTurnName}',
      unlockedNodeIds: _match.unlockedNodeIdsForCurrentPlayer,
      canUnlockNow: true,
      extraLockedHint: (nodeId) {
        final remaining = _match.turnsRemainingToUnlock(nodeId);
        return remaining != null ? 'Faltam $remaining turnos.' : null;
      },
      onUnlock: (nodeId) async {
        try {
          _match.unlockSkillForCurrentPlayer(nodeId);
          final slot = _match.isPlayerATurn ? 'a' : 'b';
          final unlockedNodeIds = _match.isPlayerATurn
              ? _match.unlockedNodeIdsForPlayerA
              : _match.unlockedNodeIdsForPlayerB;
          unawaited(_progressStore.saveUnlockedNodeIds(slot, unlockedNodeIds));
          return null;
        } on StateError catch (e) {
          return e.message;
        }
      },
    )));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_pendingOnboardingSlot != null) {
      return ElementStarterScreen(
        playerLabel: _pendingOnboardingSlot == 'a' ? 'Jogador A' : 'Jogador B',
        onConfirm: (ids) => unawaited(_confirmStartingElements(ids)),
      );
    }
    return Stack(
      children: [
        Positioned.fill(child: CustomPaint(painter: ArenaBackdropPainter())),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const PixelOutlinedText('Modo Treino', fontSize: 20),
            actions: [
              IconButton(
                icon: const Icon(Icons.auto_awesome),
                tooltip: 'Habilidades',
                onPressed: _openSkillTree,
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: PixelContentPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BattleSceneWidget(
                    view: BattleSceneView(
                      leftCurrentHp: _match.playerACurrentHp,
                      leftMaxHp: _match.playerAMaxHp,
                      rightCurrentHp: _match.playerBCurrentHp,
                      rightMaxHp: _match.playerBMaxHp,
                      isLeftTurn: _match.isPlayerATurn,
                      lastAttack: _pendingAttack,
                      leftLabel: 'Jogador A',
                      rightLabel: 'Jogador B',
                      leftStatuses: _match.playerAActiveStatuses,
                      rightStatuses: _match.playerBActiveStatuses,
                      fieldEffects: _match.activeFieldEffectBadges,
                      leftAp: _match.playerAAp,
                      leftApMax: _match.playerAApMax,
                      rightAp: _match.playerBAp,
                      rightApMax: _match.playerBApMax,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Vez de: ${_match.currentTurnName}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Descobertas: ${_match.discoveredCount}/${_match.totalCombinationsCount}',
                  ),
                  if (_match.lastTriggeredCombinationName != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Última combinação: ${_match.lastTriggeredCombinationName}',
                      ),
                    ),
                  if (_match.lastAppliedStatusNames.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Efeitos aplicados: ${_match.lastAppliedStatusNames.join(", ")}',
                      ),
                    ),
                  const Divider(height: 32),
                  if (_match.isOver)
                    ..._buildGameOver(context)
                  else
                    ..._buildPlayForm(context),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildGameOver(BuildContext context) {
    return [
      Text(
        'Fim de partida! Vencedor: ${_match.winnerName}',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 16),
      PixelMenuButton(
        label: 'Nova partida',
        onPressed: _startNewMatch,
      ),
    ];
  }

  List<Widget> _buildPlayForm(BuildContext context) {
    final elements = const ElementCatalog().all();

    return [
      Text(_selectedElementsSummary(elements)),
      const SizedBox(height: 8),
      PixelMenuButton(
        label: 'Escolher elementos',
        onPressed: () => _openElementPicker(elements),
      ),
      const SizedBox(height: 16),
      PixelMenuButton(
        label: 'Jogar',
        onPressed: _selectedIds.isEmpty ? null : _playTurn,
      ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            _error!,
            style: const TextStyle(color: Colors.red),
          ),
        ),
    ];
  }

  String _selectedElementsSummary(List<ElementOption> elements) {
    final selected = elements.where((e) => _selectedIds.contains(e.id));
    if (selected.isEmpty) return 'Nenhum elemento escolhido';
    return 'Elementos: ${selected.map((e) => '${e.symbol} ${e.name}').join(', ')}';
  }

  void _openElementPicker(List<ElementOption> elements) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final availableIds = _match.availableElementIdsForCurrentPlayer;
            return PixelSheetPanel(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const PixelOutlinedText(
                      'Escolha de 1 a 3 elementos',
                      fontSize: 18,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final element in elements)
                          if (availableIds.contains(element.id))
                            PixelElementChip(
                              label: '${element.symbol} ${element.name}',
                              selected: _selectedIds.contains(element.id),
                              onTap: () {
                                _toggleElement(element.id);
                                setSheetState(() {});
                              },
                            )
                          else
                            PixelElementChip(
                              label: '🔒 ${element.name}',
                              selected: false,
                              onTap: null,
                            ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: PixelMenuButton(
                        label: 'Confirmar',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd app && flutter test test/training_screen_test.dart`
Expected: PASS (every test in the file, including the 2 new ones).

- [ ] **Step 5: Commit**

```bash
git add app/lib/ui/training_screen.dart app/lib/ui/element_starter_screen.dart app/test/training_screen_test.dart
git commit -m "$(cat <<'EOF'
Fia a escolha inicial de elementos e o picker bloqueado na TrainingScreen (Bloco 2b)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 9: Suíte completa, verificação manual e documentação

**Files:**
- Modify: `DECISIONS.md`, `TASKS.md`

**Interfaces:**
- Nenhuma — task de fechamento, sem código novo.

- [ ] **Step 1: Rodar a suíte completa do `battle_engine`**

Run: `cd packages/battle_engine && dart analyze && dart test`
Expected: `No issues found!`, todos os testes PASS.

- [ ] **Step 2: Rodar a suíte completa do app**

Run: `cd app && flutter test && flutter analyze`
Expected: todos os testes PASS, `No issues found!`.

- [ ] **Step 3: Verificar manualmente via `flutter run -d web-server`**

Reiniciar o preview com `preview_stop` + `preview_start` completo (nunca só recarregar — não recompila). No Modo Treino, com um perfil sem `shared_preferences` prévio (ou limpando o `localStorage` do navegador primeiro):

- Confirmar que a tela de escolha inicial aparece pra Jogador A, escolher 2 elementos, confirmar.
- Confirmar que a tela aparece de novo pra Jogador B, escolher 2 elementos (pode ser os mesmos ou diferentes), confirmar.
- Confirmar que o jogo normal aparece depois disso, "Vez de: Jogador A".
- Abrir "Escolher elementos" — confirmar que os 8 elementos não escolhidos aparecem com 🔒 e não são clicáveis; os 2 escolhidos aparecem normais e selecionáveis.
- Jogar turnos (elemento sozinho, sempre livre) repetidamente até acumular 10 turnos daquele jogador.
- Abrir "Habilidades" — confirmar que um nó da branch "Elementos" ainda bloqueado por turnos mostra "Faltam N turnos." em vez do botão "Desbloquear", e que esse número desce conforme mais turnos são jogados.
- Desbloquear um elemento novo assim que o requisito é atingido — confirmar que ele aparece liberado (sem 🔒) no picker depois disso.
- Fechar e reabrir a aba (recarregar a página) — confirmar que a escolha inicial NÃO aparece de novo (já persistida) e que o elemento recém-desbloqueado continua liberado.
- Nenhum erro no console do navegador.

- [ ] **Step 4: Registrar DECISION-047 em `DECISIONS.md`**

Ler `DECISIONS.md`, localizar a última entrada (`DECISION-046`), e adicionar uma nova entrada `DECISION-047` logo depois, cobrindo:
- Bloco 2b (fora da ordem de prioridade do CLAUDE.md, sequência já combinada com o usuário desde o Bloco 2a): elementos bloqueados no Modo Treino — 2 elementos iniciais escolhidos uma vez por jogador, os outros 8 desbloqueáveis via uma nova branch "elementos" na Skill Tree (`ElementUnlock`/`ElementUnlocks`, novo `SkillGrant`), com custo crescente em turnos cumulativos jogados (`(E-1)×10`) em cima do mecanismo de pré-requisito já existente (que sozinho seria instantâneo/de graça).
- Só Modo Treino — Multiplayer aguarda o Bloco 11 (persistência real) antes de reintroduzir a mesma lacuna que o Bloco 10 já resolveu lá.
- Descoberta durante o plano: a mudança quebrou a maior parte dos testes existentes de `TrainingMatch`/`TrainingScreen` que jogavam elementos como se estivessem sempre livres — mesmo padrão do Bloco 2a, corrigido semeando `initialProgressA`/`B` (ou `SharedPreferences` já com elementos escolhidos) em cada teste afetado.
- `defaultSkillTree` cresceu de 8 pra 18 nós; `SkillTreeScreen` ganhou um hook opcional (`extraLockedHint`) pra mostrar o motivo de bloqueio além de pré-requisito, sem o Multiplayer precisar saber desse conceito.

- [ ] **Step 5: Atualizar `TASKS.md`**

Ler `TASKS.md` e mover a entrada do Bloco 2b (elementos bloqueados) pra DONE, referenciando DECISION-047. Blocos 2c/2d continuam no BACKLOG, sem alteração de texto além do que já está lá.

- [ ] **Step 6: Commit**

```bash
git add DECISIONS.md TASKS.md
git commit -m "$(cat <<'EOF'
Registra DECISION-047 e atualiza TASKS.md (elementos bloqueados)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

## Self-Review

**Cobertura do spec:**
- `ElementUnlock`/`ElementUnlocks` (novo `SkillGrant`) → Task 1.
- Branch "elementos" em `defaultSkillTree`, 10 nós sem prerequisites → Task 2.
- `SkillProgress.grantedElementIds` → Task 3.
- Contador de turnos cumulativos persistido → Task 4.
- Gate de turnos crescente (`(E-1)×10`) em `unlockSkillForCurrentPlayer`, checagem defensiva em `playElementIds`, `fromPersistedProgress`/`startNewBattleKeepingProgress` propagando o contador → Task 5.
- Tela de escolha inicial (2 elementos, uma vez por slot) → Task 6.
- `SkillTreeScreen` mostrando turnos restantes; ícones/nome da branch nova → Task 7.
- `TrainingScreen` orquestrando o onboarding, picker com cadeado, `_playTurn` salvando o contador → Task 8.
- Verificação manual + documentação → Task 9.
- Fora de escopo (Multiplayer, Blocos 2c/2d) → não implementado em nenhuma task, mantido no BACKLOG.

**Placeholder scan:** nenhum "TBD"/"depois"/passo sem código real — todo Step de código tem o trecho exato (arquivo inteiro quando a densidade de mudanças torna isso mais claro que dezenas de diffs, como em `training_match.dart`/`training_screen.dart`/`training_match_test.dart`/`training_screen_test.dart`; diffs pontuais nos arquivos menores).

**Consistência de tipos:** `ElementUnlock{id, elementId}` idêntico entre onde nasce (Task 1) e onde é consumido (Tasks 2, 3, 5); `grantedElementIds`/`availableElementIdsForCurrentPlayer`/`cumulativeTurnsPlayedA`/`B`/`turnsRemainingToUnlock` com as mesmas assinaturas em toda task que os usa; `fromPersistedProgress`'s `turnsPlayedA`/`turnsPlayedB` e `TrainingMatch`'s `initialTurnsPlayedA`/`initialTurnsPlayedB` nomeados consistentemente (o factory usa o nome mais curto porque já é óbvio que veio de disco; o construtor usa `initial` porque convive com `initialApA`/`initialProgressA` já existentes).
