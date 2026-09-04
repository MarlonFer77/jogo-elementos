# Sistema de dano/HP/condição de vitória — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give battles an end. Combinações causam dano, combatentes têm HP (base + bônus da Skill Tree), Escudo bloqueia dano, Queimadura causa dano ao longo do tempo, e uma partida termina quando alguém chega a 0 HP.

**Architecture:** Todo o núcleo (HP, dano, escudo, tick de estado, vencedor) vive em `packages/battle_engine` (Dart puro), resolvido dentro de `TurnEngine.playTurn` — o mesmo lugar que já resolve combinação e passa o turno. `AbilityEngine` não muda (já delega pro `TurnEngine` e só empilha efeito de mutação por cima). O Modo Treino (`app/`) passa a mostrar HP e a condição de vitória, calculando o HP inicial (100 + bônus de Skill Tree) e aplicando bônus de HP desbloqueado no meio da partida ao vivo.

**Tech Stack:** Dart (`packages/battle_engine`, `dart test`), Flutter (`app/`, `flutter test`).

**Spec:** `docs/superpowers/specs/2026-09-03-damage-hp-victory-design.md`

## Global Constraints

- HP base (antes de bônus): **100**
- Dano de combinação de 2 elementos (Tempestade Ígnea, Campo Eletrocutado): **20**
- Dano de combinação de 3 elementos (Lava): **35**
- Combustão: `damagePerTick: 8`, `turnsRemaining: 2` (16 de dano total, os dois ticks causam dano — inclusive o que expira o estado)
- Nó de exemplo na Skill Tree concedendo HP ("Vitalidade"): **+20** HP máximo
- Elemento único ou combinação desconhecida: **0** de dano
- Escudo bloqueia o próximo dano de combo inteiro, depois é removido; não bloqueia dano de status (DOT)
- Empate simultâneo (os dois chegam a 0 HP na mesma resolução): quem estava jogando o turno vence
- `playerAMaxHp`/`playerBMaxHp` em `BattleState.start` são opcionais, default 100 (visível na assinatura) — código de produção (`TrainingMatch`) sempre passa o valor real calculado, nunca depende do default
- `backend/src/battle-rules/` (mirror TypeScript) **não muda nesta tarefa** — fica registrado como lacuna conhecida no `DECISIONS.md` ao final
- Este projeto **não é um repositório git** (`git status` na raiz confirma). Toda "Step: Commit" em toda tarefa deste plano é opcional — tente `git status` primeiro; se não houver `.git`, pule o passo de commit e siga em frente sem criar um repositório por conta própria (isso não foi pedido).

---

## Task 1: `HpPool`

**Files:**
- Create: `packages/battle_engine/lib/src/hp_pool.dart`
- Modify: `packages/battle_engine/lib/battle_engine.dart`
- Test: `packages/battle_engine/test/hp_pool_test.dart`

**Interfaces:**
- Produces: `HpPool({required int max, required int current})`, `HpPool.isDefeated` (bool), `HpPool.withDamage(int amount)` (throws `ArgumentError` se `amount < 0`, clampa `current` em 0), `HpPool.withMaxIncreased(int amount)` (throws `ArgumentError` se `amount < 0`, soma `amount` em `max` e `current`).

- [ ] **Step 1: Write the failing test**

```dart
// packages/battle_engine/test/hp_pool_test.dart
import 'package:battle_engine/battle_engine.dart';
import 'package:test/test.dart';

void main() {
  group('HpPool', () {
    test('isDefeated is false when current is above 0', () {
      const pool = HpPool(max: 100, current: 1);
      expect(pool.isDefeated, isFalse);
    });

    test('isDefeated is true when current is 0', () {
      const pool = HpPool(max: 100, current: 0);
      expect(pool.isDefeated, isTrue);
    });

    test('withDamage subtracts from current', () {
      const pool = HpPool(max: 100, current: 100);
      final next = pool.withDamage(30);
      expect(next.current, equals(70));
      expect(next.max, equals(100));
    });

    test('withDamage clamps current at 0, never negative', () {
      const pool = HpPool(max: 100, current: 10);
      final next = pool.withDamage(999);
      expect(next.current, equals(0));
    });

    test('withDamage rejects a negative amount', () {
      const pool = HpPool(max: 100, current: 100);
      expect(() => pool.withDamage(-1), throwsArgumentError);
    });

    test('withMaxIncreased raises both max and current', () {
      const pool = HpPool(max: 100, current: 60);
      final next = pool.withMaxIncreased(20);
      expect(next.max, equals(120));
      expect(next.current, equals(80));
    });

    test('withMaxIncreased rejects a negative amount', () {
      const pool = HpPool(max: 100, current: 100);
      expect(() => pool.withMaxIncreased(-1), throwsArgumentError);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run (from `packages/battle_engine`): `dart test test/hp_pool_test.dart`
Expected: FAIL — `HpPool` isn't defined (compile error), and the file isn't exported from `battle_engine.dart` yet.

- [ ] **Step 3: Write the implementation**

```dart
// packages/battle_engine/lib/src/hp_pool.dart
/// An immutable HP pool: how much a combatant can take (`max`) and how
/// much they have left (`current`). `current` never goes below 0 or above
/// `max`. There is no healing in this engine yet — both mutating methods
/// reject a negative `amount`.
class HpPool {
  final int max;
  final int current;

  const HpPool({required this.max, required this.current});

  bool get isDefeated => current <= 0;

  /// Returns a new pool with [amount] subtracted from `current`, clamped
  /// at 0.
  HpPool withDamage(int amount) {
    if (amount < 0) {
      throw ArgumentError.value(amount, 'amount', 'must not be negative');
    }
    final next = current - amount;
    return HpPool(max: max, current: next < 0 ? 0 : next);
  }

  /// Returns a new pool with [amount] added to both `max` and `current` —
  /// used when a mid-battle bonus (e.g. a Skill Tree node) raises the
  /// ceiling; the combatant gets tougher right now, not just later.
  HpPool withMaxIncreased(int amount) {
    if (amount < 0) {
      throw ArgumentError.value(amount, 'amount', 'must not be negative');
    }
    return HpPool(max: max + amount, current: current + amount);
  }
}
```

Add the export to `packages/battle_engine/lib/battle_engine.dart` — insert this line right after `export 'src/field_effect.dart';`:

```dart
export 'src/hp_pool.dart';
```

- [ ] **Step 4: Run test to verify it passes**

Run: `dart test test/hp_pool_test.dart`
Expected: PASS (7 tests)

- [ ] **Step 5: Run the whole package's analyzer and test suite**

Run: `dart analyze` then `dart test`
Expected: `No issues found!`, all existing tests still pass (this task only adds a new file + one export line, nothing else changes).

- [ ] **Step 6: Commit**

```bash
git add packages/battle_engine/lib/src/hp_pool.dart packages/battle_engine/lib/battle_engine.dart packages/battle_engine/test/hp_pool_test.dart
git commit -m "feat(battle_engine): add HpPool"
```

(If this repo has no `.git` yet, skip this step — `git status` will confirm.)

---

## Task 2: Damage on `FieldEffect` and `ElementCombination`

**Files:**
- Modify: `packages/battle_engine/lib/src/field_effect.dart`
- Modify: `packages/battle_engine/lib/src/element_combination.dart`
- Modify: `packages/battle_engine/lib/src/default_combinations.dart`
- Test: `packages/battle_engine/test/field_effect_test.dart`
- Test: `packages/battle_engine/test/element_combination_test.dart`

**Interfaces:**
- Consumes: nothing new.
- Produces: `FieldEffect.damage` (int, default 0), `FieldEffect.copyWith({..., int? damage})`, `ElementCombination.damage` (int, default 0), `ElementCombination.result` now includes `damage`. `defaultCombinationBook`'s three combinations carry real `damage` values (20, 20, 35).

- [ ] **Step 1: Write the failing tests**

Add to the end of the `group('FieldEffect', ...)` block in `packages/battle_engine/test/field_effect_test.dart` (right before the closing `});` of that group, i.e. after the existing `copyWith changes only the given fields` test):

```dart
    test('defaults damage to 0', () {
      const effect = FieldEffect(id: 'x', name: 'X', description: 'd');
      expect(effect.damage, equals(0));
    });

    test('copyWith can change damage', () {
      const effect = FieldEffect(id: 'x', name: 'X', description: 'd');
      final next = effect.copyWith(damage: 20);
      expect(next.damage, equals(20));
    });
```

Add to the end of the `group('CombinationBook', ...)` block in `packages/battle_engine/test/element_combination_test.dart` (right before its closing `});`):

```dart
    test('the built-in combinations carry their damage value', () {
      final twoElement = defaultCombinationBook.resolve(
        [Elements.fire, Elements.wind],
      )!;
      final threeElement = defaultCombinationBook.resolve(
        [Elements.earth, Elements.fire, Elements.water],
      )!;

      expect(twoElement.damage, equals(20));
      expect(twoElement.result.damage, equals(20));
      expect(threeElement.damage, equals(35));
      expect(threeElement.result.damage, equals(35));
    });
```

Also add this test inside `group('ElementCombination', ...)` in the same file (right before its closing `});`):

```dart
    test('defaults damage to 0', () {
      final combo = ElementCombination(
        elements: [Elements.fire, Elements.wind],
        resultId: 'x',
        resultName: 'X',
        description: 'desc',
      );
      expect(combo.damage, equals(0));
    });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `dart test test/field_effect_test.dart test/element_combination_test.dart`
Expected: FAIL — `damage` doesn't exist on `FieldEffect`/`ElementCombination` yet, and the built-in combinations don't have a real damage value yet (0 != 20/35).

- [ ] **Step 3: Update `FieldEffect`**

Replace the full contents of `packages/battle_engine/lib/src/field_effect.dart` with:

```dart
/// A named effect currently active on the battlefield (not tied to a
/// specific combatant). Produced either by resolving an [ElementCombination]
/// or by an ability [Mutation].
///
/// [area] and [duration] are abstract magnitudes — this engine has no
/// spatial/tile model, so [area] is just "how big" for a future
/// presentation layer to interpret. [duration] is turns remaining on the
/// field; `null` means permanent. [damage] is the one-time damage dealt to
/// the opponent when this effect is produced by a triggered combination —
/// it is not recurring damage for as long as the effect stays on the
/// field. All three exist so a [CombinationModifier] has something
/// concrete to change (bigger area, shorter duration, more damage).
class FieldEffect {
  final String id;
  final String name;
  final String description;
  final int area;
  final int? duration;
  final int damage;

  const FieldEffect({
    required this.id,
    required this.name,
    required this.description,
    this.area = 1,
    this.duration,
    this.damage = 0,
  });

  FieldEffect copyWith({int? area, int? duration, int? damage}) {
    return FieldEffect(
      id: id,
      name: name,
      description: description,
      area: area ?? this.area,
      duration: duration ?? this.duration,
      damage: damage ?? this.damage,
    );
  }

  @override
  bool operator ==(Object other) => other is FieldEffect && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'FieldEffect($id)';
}
```

- [ ] **Step 4: Update `ElementCombination`**

Replace the full contents of `packages/battle_engine/lib/src/element_combination.dart` with:

```dart
import 'element.dart';
import 'field_effect.dart';

/// Data-driven rule mapping a set of 2 or 3 distinct [Element]s to a
/// resulting effect. Order of the input elements does not matter.
///
/// This is plain data — how a build modifies the resolved effect (area,
/// duration, damage, etc.) is a concern for a later layer, not for this
/// class.
class ElementCombination {
  final Set<Element> elements;
  final String resultId;
  final String resultName;
  final String description;
  final int damage;

  ElementCombination({
    required Iterable<Element> elements,
    required this.resultId,
    required this.resultName,
    required this.description,
    this.damage = 0,
  }) : elements = Set.unmodifiable(Set.of(elements)) {
    if (this.elements.length < 2 || this.elements.length > 3) {
      throw ArgumentError.value(
        elements,
        'elements',
        'ElementCombination requires 2 or 3 distinct elements',
      );
    }
  }

  /// The effect this combination places on the field when triggered.
  FieldEffect get result => FieldEffect(
        id: resultId,
        name: resultName,
        description: description,
        damage: damage,
      );
}
```

- [ ] **Step 5: Set damage values on the built-in combinations**

Replace the full contents of `packages/battle_engine/lib/src/default_combinations.dart` with:

```dart
import 'combination_book.dart';
import 'element_combination.dart';
import 'elements.dart';

/// Built-in combinations, from the game's design examples. Data-driven —
/// new combinations are added as entries, not as new code paths.
///
/// Damage: 2-element combinations deal 20, the 3-element one deals 35 —
/// harder to set up, pays more (see the damage/HP/victory design doc).
final defaultCombinationBook = CombinationBook([
  ElementCombination(
    elements: [Elements.fire, Elements.wind],
    resultId: 'ignited_storm',
    resultName: 'Tempestade Ígnea',
    description: 'Fogo espalhado pelo vento; dano em área.',
    damage: 20,
  ),
  ElementCombination(
    elements: [Elements.water, Elements.lightning],
    resultId: 'electrified_field',
    resultName: 'Campo Eletrocutado',
    description: 'Água carregada de eletricidade; choca quem entrar no campo.',
    damage: 20,
  ),
  ElementCombination(
    elements: [Elements.earth, Elements.fire, Elements.water],
    resultId: 'lava',
    resultName: 'Lava',
    description: 'Terra fundida pelo fogo; terreno perigoso e persistente.',
    damage: 35,
  ),
]);
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `dart test test/field_effect_test.dart test/element_combination_test.dart`
Expected: PASS

- [ ] **Step 7: Run the whole package's analyzer and test suite**

Run: `dart analyze` then `dart test`
Expected: `No issues found!`, all tests pass — including every existing test that references `defaultCombinationBook` by `resultId`/`id` only (none of them assert `damage`, so adding a nonzero value doesn't break them).

- [ ] **Step 8: Commit**

```bash
git add packages/battle_engine/lib/src/field_effect.dart packages/battle_engine/lib/src/element_combination.dart packages/battle_engine/lib/src/default_combinations.dart packages/battle_engine/test/field_effect_test.dart packages/battle_engine/test/element_combination_test.dart
git commit -m "feat(battle_engine): add damage to FieldEffect/ElementCombination"
```

---

## Task 3: `ActiveStatus.damagePerTick` and Combustão

**Files:**
- Modify: `packages/battle_engine/lib/src/active_status.dart`
- Modify: `packages/battle_engine/lib/src/mutations.dart`
- Test: `packages/battle_engine/test/active_status_test.dart`
- Test: `packages/battle_engine/test/ability_test.dart`

**Interfaces:**
- Produces: `ActiveStatus.damagePerTick` (int, default 0, preserved across `tick()`). `Mutations.combustion` now applies `ActiveStatus(effect: StatusEffects.burn, turnsRemaining: 2, damagePerTick: 8)`.

- [ ] **Step 1: Write the failing tests**

Add to the end of the `group('ActiveStatus', ...)` block in `packages/battle_engine/test/active_status_test.dart` (before its closing `});`):

```dart
    test('defaults damagePerTick to 0', () {
      final status = ActiveStatus(effect: StatusEffects.burn);
      expect(status.damagePerTick, equals(0));
    });

    test('rejects a negative damagePerTick', () {
      expect(
        () => ActiveStatus(effect: StatusEffects.burn, damagePerTick: -1),
        throwsArgumentError,
      );
    });

    test('tick preserves damagePerTick', () {
      final status = ActiveStatus(
        effect: StatusEffects.burn,
        turnsRemaining: 2,
        damagePerTick: 8,
      );
      final ticked = status.tick();
      expect(ticked.damagePerTick, equals(8));
    });
```

Add to the end of the `group('Mutations', ...)` block in `packages/battle_engine/test/ability_test.dart` (before its closing `});`):

```dart
    test('combustion\'s burn status deals 8 damage per tick for 2 ticks',
        () {
      const effect = AbilityEffect();
      final result = Mutations.combustion.apply(effect);

      final burn = result.statusesToApply.single;
      expect(burn.damagePerTick, equals(8));
      expect(burn.turnsRemaining, equals(2));
    });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `dart test test/active_status_test.dart test/ability_test.dart`
Expected: FAIL — `damagePerTick` doesn't exist yet, and `Mutations.combustion`'s burn status doesn't carry damage yet.

- [ ] **Step 3: Update `ActiveStatus`**

Replace the full contents of `packages/battle_engine/lib/src/active_status.dart` with:

```dart
import 'status_effect.dart';

/// An instance of a [StatusEffect] applied to a target. [turnsRemaining]
/// counts down by 1 on each [tick]; `null` means it lasts until removed
/// explicitly (e.g. a Shield consumed on hit, not by turn count).
/// [damagePerTick] is how much damage this instance deals every time it
/// ticks (0 for statuses that don't damage, e.g. Shield) — set per
/// instance, not fixed by [StatusEffect] kind, so a stronger source could
/// apply a harsher Burn than a weaker one.
class ActiveStatus {
  final StatusEffect effect;
  final int? turnsRemaining;
  final int damagePerTick;

  ActiveStatus({
    required this.effect,
    this.turnsRemaining,
    this.damagePerTick = 0,
  }) {
    if (turnsRemaining != null && turnsRemaining! < 0) {
      throw ArgumentError.value(
        turnsRemaining,
        'turnsRemaining',
        'must be null or 0 or greater',
      );
    }
    if (damagePerTick < 0) {
      throw ArgumentError.value(
        damagePerTick,
        'damagePerTick',
        'must not be negative',
      );
    }
  }

  bool get isExpired => turnsRemaining != null && turnsRemaining! <= 0;

  /// Returns a copy with [turnsRemaining] decremented by 1, or the same
  /// instance if it has no duration (permanent until removed).
  ActiveStatus tick() {
    if (turnsRemaining == null) return this;
    return ActiveStatus(
      effect: effect,
      turnsRemaining: turnsRemaining! - 1,
      damagePerTick: damagePerTick,
    );
  }
}
```

- [ ] **Step 4: Give Combustão a real damage value**

In `packages/battle_engine/lib/src/mutations.dart`, replace the `combustion` field with:

```dart
  static final combustion = Mutation(
    id: 'combustion',
    name: 'Combustão',
    description: 'Aplica queimadura ao alvo (8 de dano por 2 turnos).',
    apply: (effect) => effect.copyWith(
      statusesToApply: [
        ...effect.statusesToApply,
        ActiveStatus(
          effect: StatusEffects.burn,
          turnsRemaining: 2,
          damagePerTick: 8,
        ),
      ],
    ),
  );
```

(Only the `description` string and the `ActiveStatus(...)` call inside `apply` change — `fragmentation`, `wildfire`, `unstableCore` and `all` stay exactly as they are.)

- [ ] **Step 5: Run tests to verify they pass**

Run: `dart test test/active_status_test.dart test/ability_test.dart`
Expected: PASS

- [ ] **Step 6: Run the whole package's analyzer and test suite**

Run: `dart analyze` then `dart test`
Expected: `No issues found!`, all tests pass (the existing `combustion adds a burn status without touching other fields` test only checks `.effect`, not `.damagePerTick`, so it's unaffected).

- [ ] **Step 7: Commit**

```bash
git add packages/battle_engine/lib/src/active_status.dart packages/battle_engine/lib/src/mutations.dart packages/battle_engine/test/active_status_test.dart packages/battle_engine/test/ability_test.dart
git commit -m "feat(battle_engine): add damagePerTick to ActiveStatus, wire it into Combustão"
```

---

## Task 4: HP and win condition on `BattleState`

**Files:**
- Modify: `packages/battle_engine/lib/src/battle_state.dart`
- Test: `packages/battle_engine/test/battle_state_test.dart`

**Interfaces:**
- Consumes: `HpPool` (Task 1).
- Produces: `BattleState.hp` (`Map<Combatant, HpPool>`), `BattleState.winner` (`Combatant?`), `BattleState.start({..., int playerAMaxHp = 100, int playerBMaxHp = 100})`, `BattleState.hpOf(Combatant)`, `BattleState.withDamage(Combatant target, int amount)`, `BattleState.withMaxHpIncreased(Combatant target, int amount)`, `BattleState.copyWith({..., Map<Combatant, HpPool>? hp, Combatant? winner})`.

- [ ] **Step 1: Write the failing tests**

Add these new groups to the end of `packages/battle_engine/test/battle_state_test.dart`, right before the final closing `}` of `main()`:

```dart
  group('BattleState HP', () {
    test('start defaults both players to 100/100 HP', () {
      final state = BattleState.start(playerA: playerA, playerB: playerB);
      expect(state.hpOf(playerA).max, equals(100));
      expect(state.hpOf(playerA).current, equals(100));
      expect(state.hpOf(playerB).max, equals(100));
      expect(state.hpOf(playerB).current, equals(100));
    });

    test('start accepts different max HP per player', () {
      final state = BattleState.start(
        playerA: playerA,
        playerB: playerB,
        playerAMaxHp: 120,
        playerBMaxHp: 80,
      );
      expect(state.hpOf(playerA).max, equals(120));
      expect(state.hpOf(playerB).max, equals(80));
    });

    test('start sets winner to null', () {
      final state = BattleState.start(playerA: playerA, playerB: playerB);
      expect(state.winner, isNull);
    });

    test('hpOf throws for a combatant outside the battle', () {
      final state = BattleState.start(playerA: playerA, playerB: playerB);
      const stranger = Combatant(id: 'c', name: 'Carla');
      expect(() => state.hpOf(stranger), throwsArgumentError);
    });

    test('withDamage reduces only the target\'s current HP', () {
      final state = BattleState.start(playerA: playerA, playerB: playerB);
      final next = state.withDamage(playerB, 30);

      expect(next.hpOf(playerB).current, equals(70));
      expect(next.hpOf(playerA).current, equals(100));
      expect(state.hpOf(playerB).current, equals(100)); // original unchanged
    });

    test('withDamage sets the opponent as winner when it defeats the '
        'target', () {
      final state = BattleState.start(playerA: playerA, playerB: playerB);
      final next = state.withDamage(playerB, 100);

      expect(next.hpOf(playerB).isDefeated, isTrue);
      expect(next.winner, equals(playerA));
    });

    test('withDamage does not overwrite an existing winner', () {
      final state = BattleState.start(playerA: playerA, playerB: playerB)
          .withDamage(playerB, 100); // playerA already won
      final next = state.withDamage(playerA, 100); // playerA also drops to 0

      expect(next.hpOf(playerA).isDefeated, isTrue);
      expect(next.winner, equals(playerA)); // unchanged, first winner sticks
    });

    test('withMaxHpIncreased raises both max and current for the target '
        'only', () {
      final state = BattleState.start(playerA: playerA, playerB: playerB);
      final next = state.withMaxHpIncreased(playerA, 20);

      expect(next.hpOf(playerA).max, equals(120));
      expect(next.hpOf(playerA).current, equals(120));
      expect(next.hpOf(playerB).max, equals(100));
    });

    test('copyWith preserves hp and winner when not specified', () {
      final state = BattleState.start(playerA: playerA, playerB: playerB)
          .withDamage(playerB, 30);
      final next = state.copyWith(currentTurn: playerB);

      expect(next.hpOf(playerB).current, equals(70));
      expect(next.winner, equals(state.winner));
    });
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `dart test test/battle_state_test.dart`
Expected: FAIL — `hp`, `winner`, `hpOf`, `withDamage`, `withMaxHpIncreased` and the new `.start()` parameters don't exist yet.

- [ ] **Step 3: Implement**

Replace the full contents of `packages/battle_engine/lib/src/battle_state.dart` with:

```dart
import 'active_status.dart';
import 'combatant.dart';
import 'field_effect.dart';
import 'hp_pool.dart';
import 'status_effect.dart';

/// Snapshot of an in-progress 1v1 battle: the two participants, any active
/// field effects (produced by element combinations or ability mutations),
/// the status effects and HP of each combatant, whose turn it is, and who
/// won (if the battle is over).
///
/// Pure data, immutable. Turn order, damage resolution and win/loss belong
/// to [TurnEngine] — this class only represents a valid state and how to
/// derive the next one.
class BattleState {
  final Combatant playerA;
  final Combatant playerB;
  final Combatant currentTurn;
  final List<FieldEffect> activeFieldEffects;
  final Map<Combatant, List<ActiveStatus>> combatantStatuses;
  final Map<Combatant, HpPool> hp;
  final Combatant? winner;

  BattleState({
    required this.playerA,
    required this.playerB,
    required this.currentTurn,
    List<FieldEffect> activeFieldEffects = const [],
    Map<Combatant, List<ActiveStatus>>? combatantStatuses,
    Map<Combatant, HpPool>? hp,
    this.winner,
  })  : activeFieldEffects = List.unmodifiable(activeFieldEffects),
        combatantStatuses = Map<Combatant, List<ActiveStatus>>.unmodifiable({
          playerA: List<ActiveStatus>.unmodifiable(
            combatantStatuses?[playerA] ?? const <ActiveStatus>[],
          ),
          playerB: List<ActiveStatus>.unmodifiable(
            combatantStatuses?[playerB] ?? const <ActiveStatus>[],
          ),
        }),
        hp = Map<Combatant, HpPool>.unmodifiable({
          playerA: hp?[playerA] ?? const HpPool(max: 100, current: 100),
          playerB: hp?[playerB] ?? const HpPool(max: 100, current: 100),
        }) {
    if (playerA == playerB) {
      throw ArgumentError('playerA and playerB must be distinct combatants');
    }
    if (currentTurn != playerA && currentTurn != playerB) {
      throw ArgumentError('currentTurn must be playerA or playerB');
    }
  }

  /// Starts a new battle with an empty field, no statuses, [playerA]
  /// acting first. [playerAMaxHp]/[playerBMaxHp] default to 100 — a
  /// convenience for callers that don't care about HP (most tests). Real
  /// gameplay always computes and passes the real value (base + Skill
  /// Tree bonus) explicitly; nothing in production code relies on this
  /// default.
  factory BattleState.start({
    required Combatant playerA,
    required Combatant playerB,
    int playerAMaxHp = 100,
    int playerBMaxHp = 100,
  }) {
    return BattleState(
      playerA: playerA,
      playerB: playerB,
      currentTurn: playerA,
      hp: {
        playerA: HpPool(max: playerAMaxHp, current: playerAMaxHp),
        playerB: HpPool(max: playerBMaxHp, current: playerBMaxHp),
      },
    );
  }

  BattleState copyWith({
    Combatant? currentTurn,
    List<FieldEffect>? activeFieldEffects,
    Map<Combatant, List<ActiveStatus>>? combatantStatuses,
    Map<Combatant, HpPool>? hp,
    Combatant? winner,
  }) {
    return BattleState(
      playerA: playerA,
      playerB: playerB,
      currentTurn: currentTurn ?? this.currentTurn,
      activeFieldEffects: activeFieldEffects ?? this.activeFieldEffects,
      combatantStatuses: combatantStatuses ?? this.combatantStatuses,
      hp: hp ?? this.hp,
      winner: winner ?? this.winner,
    );
  }

  /// Returns a new state with [effect] added to the field.
  BattleState withFieldEffect(FieldEffect effect) {
    return copyWith(activeFieldEffects: [...activeFieldEffects, effect]);
  }

  /// Returns the other participant relative to [combatant].
  Combatant opponentOf(Combatant combatant) {
    if (combatant == playerA) return playerB;
    if (combatant == playerB) return playerA;
    throw ArgumentError.value(
      combatant,
      'combatant',
      'is not part of this battle',
    );
  }

  /// Active statuses currently applied to [combatant].
  List<ActiveStatus> statusesOf(Combatant combatant) {
    _requireParticipant(combatant);
    return combatantStatuses[combatant] ?? const [];
  }

  /// Whether [combatant] currently has [effect] applied.
  bool hasStatus(Combatant combatant, StatusEffect effect) {
    return statusesOf(combatant).any((status) => status.effect == effect);
  }

  /// Returns a new state with [status] applied to [target].
  BattleState withStatusApplied(Combatant target, ActiveStatus status) {
    _requireParticipant(target);
    final updated = Map<Combatant, List<ActiveStatus>>.from(
      combatantStatuses,
    );
    updated[target] = [...statusesOf(target), status];
    return copyWith(combatantStatuses: updated);
  }

  /// Returns a new state with every active instance of [effect] removed
  /// from [target].
  BattleState withStatusRemoved(Combatant target, StatusEffect effect) {
    _requireParticipant(target);
    final updated = Map<Combatant, List<ActiveStatus>>.from(
      combatantStatuses,
    );
    updated[target] =
        statusesOf(target).where((status) => status.effect != effect).toList();
    return copyWith(combatantStatuses: updated);
  }

  /// Ticks every active status for both combatants by one turn, removing
  /// any that expire. Callers decide when this should run.
  BattleState withStatusesTicked() {
    final updated = <Combatant, List<ActiveStatus>>{
      for (final combatant in [playerA, playerB])
        combatant: statusesOf(combatant)
            .map((status) => status.tick())
            .where((status) => !status.isExpired)
            .toList(),
    };
    return copyWith(combatantStatuses: updated);
  }

  /// HP pool of [combatant].
  HpPool hpOf(Combatant combatant) {
    _requireParticipant(combatant);
    return hp[combatant]!;
  }

  /// Returns a new state with [amount] of damage applied to [target]. If
  /// this brings [target] to 0 HP and nobody has won yet, [target]'s
  /// opponent becomes the winner. Never un-sets an existing winner.
  BattleState withDamage(Combatant target, int amount) {
    _requireParticipant(target);
    final updatedPool = hpOf(target).withDamage(amount);
    final updatedHp = Map<Combatant, HpPool>.from(hp)..[target] = updatedPool;
    final newWinner = (winner == null && updatedPool.isDefeated)
        ? opponentOf(target)
        : winner;
    return copyWith(hp: updatedHp, winner: newWinner);
  }

  /// Returns a new state with [target]'s max (and current) HP increased by
  /// [amount] — used when a mid-battle bonus (e.g. a Skill Tree node)
  /// raises the ceiling.
  BattleState withMaxHpIncreased(Combatant target, int amount) {
    _requireParticipant(target);
    final updatedHp = Map<Combatant, HpPool>.from(hp)
      ..[target] = hpOf(target).withMaxIncreased(amount);
    return copyWith(hp: updatedHp);
  }

  void _requireParticipant(Combatant combatant) {
    if (combatant != playerA && combatant != playerB) {
      throw ArgumentError.value(
        combatant,
        'combatant',
        'is not part of this battle',
      );
    }
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `dart test test/battle_state_test.dart`
Expected: PASS

- [ ] **Step 5: Run the whole package's analyzer and test suite**

Run: `dart analyze` then `dart test`
Expected: `No issues found!`, all tests pass — including the two tests that call the raw `BattleState(...)` constructor without `hp` (they get the 100/100 default and don't assert on it).

- [ ] **Step 6: Commit**

```bash
git add packages/battle_engine/lib/src/battle_state.dart packages/battle_engine/test/battle_state_test.dart
git commit -m "feat(battle_engine): add HP and win condition to BattleState"
```

---

## Task 5: Damage, Escudo, DOT tick and win condition in `TurnEngine`

**Files:**
- Modify: `packages/battle_engine/lib/src/turn_engine.dart`
- Modify: `packages/battle_engine/lib/src/ability_engine.dart` (doc comment only)
- Test: `packages/battle_engine/test/turn_engine_test.dart`

**Interfaces:**
- Consumes: `BattleState.withDamage`, `BattleState.hasStatus`, `BattleState.withStatusRemoved`, `BattleState.statusesOf`, `BattleState.withStatusesTicked`, `BattleState.winner` (Task 4); `FieldEffect.damage` (Task 2); `ActiveStatus.damagePerTick` (Task 3); `StatusEffects.shield` (already exists).
- Produces: `TurnEngine.playTurn` now applies combo damage (respecting Escudo), ticks DOT status damage automatically, and throws `StateError` if `state.winner != null`.

- [ ] **Step 1: Write the failing tests**

Add these new tests inside the existing `group('TurnEngine.playTurn', ...)` block in `packages/battle_engine/test/turn_engine_test.dart`, right before its closing `});`:

```dart
    test('a known 2-element combination deals 20 damage to the opponent',
        () {
      final state = BattleState.start(playerA: playerA, playerB: playerB);
      final action = TurnAction(
        actor: playerA,
        elements: [Elements.fire, Elements.wind],
      );

      final result = engine.playTurn(state, action);

      expect(result.state.hpOf(playerB).current, equals(80));
      expect(result.state.hpOf(playerA).current, equals(100));
    });

    test('the 3-element combination deals 35 damage', () {
      final state = BattleState.start(playerA: playerA, playerB: playerB);
      final action = TurnAction(
        actor: playerA,
        elements: [Elements.earth, Elements.fire, Elements.water],
      );

      final result = engine.playTurn(state, action);

      expect(result.state.hpOf(playerB).current, equals(65));
    });

    test('a single element or an unknown combination deals no damage', () {
      final state = BattleState.start(playerA: playerA, playerB: playerB);

      final afterSingle = engine
          .playTurn(
            state,
            TurnAction(actor: playerA, elements: [Elements.fire]),
          )
          .state;
      expect(afterSingle.hpOf(playerB).current, equals(100));

      final afterUnknown = engine
          .playTurn(
            afterSingle,
            TurnAction(
              actor: playerB,
              elements: [Elements.ice, Elements.shadow],
            ),
          )
          .state;
      expect(afterUnknown.hpOf(playerA).current, equals(100));
    });

    test('Shield blocks the next combo damage and is consumed', () {
      final state = BattleState.start(playerA: playerA, playerB: playerB)
          .withStatusApplied(playerB, ActiveStatus(effect: StatusEffects.shield));
      final action = TurnAction(
        actor: playerA,
        elements: [Elements.fire, Elements.wind],
      );

      final result = engine.playTurn(state, action);

      expect(result.state.hpOf(playerB).current, equals(100));
      expect(result.state.hasStatus(playerB, StatusEffects.shield), isFalse);
    });

    test('Shield does not block a second hit after being consumed', () {
      var state = BattleState.start(playerA: playerA, playerB: playerB)
          .withStatusApplied(playerB, ActiveStatus(effect: StatusEffects.shield));

      state = engine
          .playTurn(
            state,
            TurnAction(actor: playerA, elements: [Elements.fire, Elements.wind]),
          )
          .state; // blocked, shield consumed
      state = engine
          .playTurn(
            state,
            TurnAction(actor: playerB, elements: [Elements.ice]),
          )
          .state; // no-op action, just passes the turn back
      state = engine
          .playTurn(
            state,
            TurnAction(actor: playerA, elements: [Elements.fire, Elements.wind]),
          )
          .state; // not blocked this time

      expect(state.hpOf(playerB).current, equals(80));
    });

    test('a status with damagePerTick damages its owner at the end of '
        'every playTurn call, including the tick that expires it', () {
      var state = BattleState.start(playerA: playerA, playerB: playerB)
          .withStatusApplied(
            playerB,
            ActiveStatus(
              effect: StatusEffects.burn,
              turnsRemaining: 2,
              damagePerTick: 8,
            ),
          );

      state = engine
          .playTurn(state, TurnAction(actor: playerA, elements: [Elements.fire]))
          .state;
      expect(state.hpOf(playerB).current, equals(92)); // first tick

      state = engine
          .playTurn(state, TurnAction(actor: playerB, elements: [Elements.water]))
          .state;
      expect(state.hpOf(playerB).current, equals(84)); // second tick, expires
      expect(state.hasStatus(playerB, StatusEffects.burn), isFalse);
    });

    test('combo damage can set a winner', () {
      final state = BattleState.start(
        playerA: playerA,
        playerB: playerB,
        playerBMaxHp: 15,
      );
      final result = engine.playTurn(
        state,
        TurnAction(actor: playerA, elements: [Elements.fire, Elements.wind]),
      );

      expect(result.state.hpOf(playerB).isDefeated, isTrue);
      expect(result.state.winner, equals(playerA));
    });

    test('DOT damage alone can set a winner', () {
      var state = BattleState.start(
        playerA: playerA,
        playerB: playerB,
        playerBMaxHp: 5,
      ).withStatusApplied(
        playerB,
        ActiveStatus(effect: StatusEffects.burn, turnsRemaining: 1, damagePerTick: 8),
      );

      final result = engine.playTurn(
        state,
        TurnAction(actor: playerA, elements: [Elements.ice]),
      );

      expect(result.state.winner, equals(playerA));
    });

    test('when DOT ticks would defeat both combatants in the same '
        'resolution, the actor wins the tie', () {
      // Both start lethal-low on HP, both carry a lethal DOT — the action
      // itself deals no combo damage (single element), so this isolates
      // the tie strictly to the DOT tick ordering.
      final state = BattleState.start(
        playerA: playerA,
        playerB: playerB,
        playerAMaxHp: 5,
        playerBMaxHp: 5,
      ).withStatusApplied(
        playerA,
        ActiveStatus(effect: StatusEffects.burn, turnsRemaining: 1, damagePerTick: 8),
      ).withStatusApplied(
        playerB,
        ActiveStatus(effect: StatusEffects.burn, turnsRemaining: 1, damagePerTick: 8),
      );

      final result = engine.playTurn(
        state,
        TurnAction(actor: playerA, elements: [Elements.ice]),
      );

      expect(result.state.hpOf(playerA).isDefeated, isTrue);
      expect(result.state.hpOf(playerB).isDefeated, isTrue);
      expect(result.state.winner, equals(playerA));
    });

    test('playTurn throws once the battle already has a winner', () {
      final state = BattleState.start(
        playerA: playerA,
        playerB: playerB,
        playerBMaxHp: 1,
      );
      final finished = engine
          .playTurn(
            state,
            TurnAction(actor: playerA, elements: [Elements.fire, Elements.wind]),
          )
          .state;
      expect(finished.winner, equals(playerA));

      expect(
        () => engine.playTurn(
          finished,
          TurnAction(actor: playerB, elements: [Elements.water]),
        ),
        throwsStateError,
      );
    });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `dart test test/turn_engine_test.dart`
Expected: FAIL — `playTurn` doesn't apply damage, doesn't check Shield, doesn't tick DOT, and doesn't reject actions after a winner is set.

- [ ] **Step 3: Implement**

Replace the full contents of `packages/battle_engine/lib/src/turn_engine.dart` with:

```dart
import 'battle_state.dart';
import 'combatant.dart';
import 'combination_book.dart';
import 'combination_modifier.dart';
import 'status_effect.dart';
import 'turn_action.dart';
import 'turn_result.dart';

/// Resolves one turn at a time. Pure logic: given a state and an action,
/// produces the next state — including combination damage, Escudo
/// blocking, status damage-over-time ticks, and the win condition. Does
/// not know about Skill Tree/Build (mutations/combination modifiers are
/// passed in by the caller) or about persistence/the backend.
class TurnEngine {
  final CombinationBook combinationBook;

  const TurnEngine(this.combinationBook);

  /// Resolves [action] against [state]:
  /// - rejects it if the battle already has a [BattleState.winner]
  /// - rejects it if it's not [TurnAction.actor]'s turn
  /// - resolves a combination from the played elements, if 2 or 3 were played
  /// - runs the triggered combination's [FieldEffect] through
  ///   [combinationModifiers], in order (bigger area, shorter duration...)
  /// - adds the (possibly modified) effect to the field
  /// - if it deals damage, applies it to the opponent — unless the
  ///   opponent has an active Escudo, which blocks the hit entirely and
  ///   is then consumed
  /// - passes the turn to the opponent
  /// - ticks every active status for both combatants, applying each
  ///   status's `damagePerTick` to its owner (including the tick that
  ///   expires it)
  /// - sets [BattleState.winner] the moment either combatant's HP reaches
  ///   0; if both would be defeated in the same resolution, [action]'s
  ///   actor wins the tie
  TurnResult playTurn(
    BattleState state,
    TurnAction action, {
    List<CombinationModifier> combinationModifiers = const [],
  }) {
    if (state.winner != null) {
      throw StateError('The battle is already over');
    }
    if (action.actor != state.currentTurn) {
      throw StateError('It is not ${action.actor}\'s turn');
    }

    final combination = action.elements.length >= 2
        ? combinationBook.resolve(action.elements)
        : null;

    final opponent = state.opponentOf(action.actor);
    var nextState = state.copyWith(currentTurn: opponent);

    if (combination != null) {
      var fieldEffect = combination.result;
      for (final modifier in combinationModifiers) {
        fieldEffect = modifier.apply(fieldEffect);
      }
      nextState = nextState.withFieldEffect(fieldEffect);
      nextState = _applyComboDamage(nextState, opponent, fieldEffect.damage);
    }

    nextState = _tickStatusDamage(nextState, action.actor);

    return TurnResult(state: nextState, triggeredCombination: combination);
  }

  BattleState _applyComboDamage(
    BattleState state,
    Combatant target,
    int damage,
  ) {
    if (damage <= 0) return state;

    if (state.hasStatus(target, StatusEffects.shield)) {
      return state.withStatusRemoved(target, StatusEffects.shield);
    }
    return state.withDamage(target, damage);
  }

  /// Ticks damage-over-time statuses for both combatants. [actor] is
  /// processed last so that, if both combatants would be defeated by this
  /// same tick, [BattleState.withDamage]'s "first defeat sets the winner"
  /// rule makes the actor the winner (see the class doc).
  BattleState _tickStatusDamage(BattleState state, Combatant actor) {
    var result = state;
    final opponent = state.opponentOf(actor);
    for (final combatant in [opponent, actor]) {
      for (final status in state.statusesOf(combatant)) {
        if (status.damagePerTick > 0) {
          result = result.withDamage(combatant, status.damagePerTick);
        }
      }
    }
    return result.withStatusesTicked();
  }
}
```

- [ ] **Step 4: Update `AbilityEngine`'s doc comment**

In `packages/battle_engine/lib/src/ability_engine.dart`, the class doc comment currently reads:

```dart
/// Resolves the use of an [Ability]: plays its base elements as a normal
/// turn (via [TurnEngine], so combinations still trigger and the turn still
/// passes), then applies whatever its mutations add — field effects and
/// statuses on the opponent. Does not know about damage, HP or crit rolls;
/// [AbilityEffect.hitCount] and [AbilityEffect.critChanceBonus] are just
/// carried through for a future combat system to read.
```

Replace it with:

```dart
/// Resolves the use of an [Ability]: plays its base elements as a normal
/// turn (via [TurnEngine], so combinations still trigger, combo damage and
/// the win condition are already resolved, and the turn still passes),
/// then applies whatever its mutations add — field effects and statuses on
/// the opponent. [AbilityEffect.hitCount] and [AbilityEffect.critChanceBonus]
/// are still not consumed by anything; they're carried through for a
/// future combat system to read.
```

No other change to this file — `useAbility`'s body is unchanged, it already just uses `turnResult.state` as-is.

- [ ] **Step 5: Run tests to verify they pass**

Run: `dart test test/turn_engine_test.dart test/ability_engine_test.dart`
Expected: PASS

- [ ] **Step 6: Run the whole package's analyzer and test suite**

Run: `dart analyze` then `dart test`
Expected: `No issues found!`, all tests pass.

- [ ] **Step 7: Commit**

```bash
git add packages/battle_engine/lib/src/turn_engine.dart packages/battle_engine/lib/src/ability_engine.dart packages/battle_engine/test/turn_engine_test.dart
git commit -m "feat(battle_engine): resolve damage, Escudo, DOT ticks and win condition in TurnEngine"
```

---

## Task 6: HP bonus from the Skill Tree (`MaxHpBonus`)

**Files:**
- Create: `packages/battle_engine/lib/src/max_hp_bonus.dart`
- Create: `packages/battle_engine/lib/src/max_hp_bonuses.dart`
- Modify: `packages/battle_engine/lib/src/skill_progress.dart`
- Modify: `packages/battle_engine/lib/src/default_skill_tree.dart`
- Modify: `packages/battle_engine/lib/battle_engine.dart`
- Test: `packages/battle_engine/test/max_hp_bonus_test.dart`
- Test: `packages/battle_engine/test/skill_progress_test.dart`
- Test: `packages/battle_engine/test/default_skill_tree_test.dart`

**Interfaces:**
- Consumes: `SkillGrant` (existing interface).
- Produces: `MaxHpBonus implements SkillGrant` (`id`, `name`, `description`, `bonus`), `MaxHpBonuses.vitality` (`bonus: 20`), `SkillProgress.grantedMaxHpBonus` (int), `defaultSkillTree` node `'vitality_training'` granting `MaxHpBonuses.vitality`.

- [ ] **Step 1: Write the failing test for `MaxHpBonus`/`MaxHpBonuses`**

```dart
// packages/battle_engine/test/max_hp_bonus_test.dart
import 'package:battle_engine/battle_engine.dart';
import 'package:test/test.dart';

void main() {
  group('MaxHpBonus', () {
    test('two bonuses with the same id are equal', () {
      const a = MaxHpBonus(id: 'x', name: 'X', description: 'a', bonus: 10);
      const b = MaxHpBonus(id: 'x', name: 'Outro nome', description: 'b', bonus: 99);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('MaxHpBonuses', () {
    test('vitality grants 20 HP', () {
      expect(MaxHpBonuses.vitality.bonus, equals(20));
    });

    test('all built-in bonuses have unique ids', () {
      final ids = MaxHpBonuses.all.map((b) => b.id).toSet();
      expect(ids.length, equals(MaxHpBonuses.all.length));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `dart test test/max_hp_bonus_test.dart`
Expected: FAIL — `MaxHpBonus`/`MaxHpBonuses` don't exist yet.

- [ ] **Step 3: Implement `MaxHpBonus`**

```dart
// packages/battle_engine/lib/src/max_hp_bonus.dart
import 'skill_grant.dart';

/// A modifier a Skill Tree node can grant that raises a combatant's max
/// HP. The build-level counterpart to [Mutation]/[CombinationModifier], but
/// plain data (no function to apply) — [BattleState.withMaxHpIncreased]
/// does the actual work, driven by whoever is orchestrating the match
/// (e.g. `TrainingMatch`).
class MaxHpBonus implements SkillGrant {
  @override
  final String id;
  final String name;
  final String description;
  final int bonus;

  const MaxHpBonus({
    required this.id,
    required this.name,
    required this.description,
    required this.bonus,
  });

  @override
  bool operator ==(Object other) => other is MaxHpBonus && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'MaxHpBonus($id)';
}
```

- [ ] **Step 4: Implement `MaxHpBonuses`**

```dart
// packages/battle_engine/lib/src/max_hp_bonuses.dart
import 'max_hp_bonus.dart';

/// Built-in max HP bonuses. Data-driven — new bonuses are added as
/// entries here, not as new logic.
class MaxHpBonuses {
  MaxHpBonuses._();

  static const vitality = MaxHpBonus(
    id: 'vitality',
    name: 'Vitalidade',
    description: 'Aumenta o HP máximo em 20.',
    bonus: 20,
  );

  static const List<MaxHpBonus> all = [vitality];
}
```

- [ ] **Step 5: Export both from `battle_engine.dart`**

In `packages/battle_engine/lib/battle_engine.dart`, insert these two lines right after `export 'src/hp_pool.dart';`:

```dart
export 'src/max_hp_bonus.dart';
export 'src/max_hp_bonuses.dart';
```

- [ ] **Step 6: Run test to verify it passes**

Run: `dart test test/max_hp_bonus_test.dart`
Expected: PASS

- [ ] **Step 7: Write the failing test for `SkillProgress.grantedMaxHpBonus`**

Add this new node to the `buildTree()` helper in `packages/battle_engine/test/skill_progress_test.dart` — insert it right after the `elemental_insight` node, before the closing `]);` of the `SkillTree([...])` list:

```dart
      SkillNode(
        id: 'vitality_training',
        name: 'Treino de Vitalidade',
        description: 'x',
        branch: 'vitalidade',
        grants: MaxHpBonuses.vitality,
      ),
```

Add this new group at the end of the file, right before the final closing `}` of `main()`:

```dart
  group('SkillProgress.grantedMaxHpBonus', () {
    test('is 0 with nothing unlocked', () {
      final progress = SkillProgress(buildTree());
      expect(progress.grantedMaxHpBonus, equals(0));
    });

    test('reflects an unlocked MaxHpBonus node', () {
      final progress =
          SkillProgress(buildTree()).unlock('vitality_training');
      expect(progress.grantedMaxHpBonus, equals(20));
    });

    test('ignores nodes that grant a Mutation or CombinationModifier', () {
      final progress = SkillProgress(buildTree()).unlock('ember_mastery');
      expect(progress.grantedMaxHpBonus, equals(0));
    });
  });
```

- [ ] **Step 8: Run test to verify it fails**

Run: `dart test test/skill_progress_test.dart`
Expected: FAIL — `grantedMaxHpBonus` doesn't exist yet.

- [ ] **Step 9: Implement `SkillProgress.grantedMaxHpBonus`**

Replace the full contents of `packages/battle_engine/lib/src/skill_progress.dart` with:

```dart
import 'combination_modifier.dart';
import 'max_hp_bonus.dart';
import 'mutation.dart';
import 'skill_node.dart';
import 'skill_tree.dart';

/// Tracks which [SkillNode]s a single build has unlocked in a [SkillTree].
/// Immutable — [unlock] returns a new [SkillProgress]. Two players can use
/// the same tree and end up with completely different unlocked nodes, and
/// therefore different [grantedMutations]/[grantedCombinationModifiers]/
/// [grantedMaxHpBonus].
class SkillProgress {
  final SkillTree tree;
  final List<String> unlockedNodeIds;

  SkillProgress(this.tree, {List<String> unlockedNodeIds = const []})
      : unlockedNodeIds = List.unmodifiable(unlockedNodeIds);

  bool isUnlocked(String nodeId) => unlockedNodeIds.contains(nodeId);

  /// Whether [nodeId] exists, isn't unlocked yet, and has every prerequisite
  /// already unlocked.
  bool canUnlock(String nodeId) {
    final node = tree.nodeById(nodeId);
    if (node == null || isUnlocked(nodeId)) return false;
    return node.prerequisites.every(isUnlocked);
  }

  /// Returns new progress with [nodeId] unlocked.
  SkillProgress unlock(String nodeId) {
    if (!canUnlock(nodeId)) {
      throw StateError('Cannot unlock "$nodeId" yet');
    }
    return SkillProgress(tree, unlockedNodeIds: [...unlockedNodeIds, nodeId]);
  }

  /// Nodes currently unlockable: prerequisites met, not yet unlocked.
  List<SkillNode> get availableNodes =>
      tree.availableFrom(unlockedNodeIds.toSet());

  /// Mutations granted by unlocked nodes (nodes that grant a
  /// [CombinationModifier] or [MaxHpBonus] instead are skipped here), in
  /// unlock order, deduplicated by id.
  List<Mutation> get grantedMutations {
    return _grantedOfType<Mutation>((grant) => grant.id);
  }

  /// Combination modifiers granted by unlocked nodes (nodes that grant a
  /// [Mutation] or [MaxHpBonus] instead are skipped here), in unlock order,
  /// deduplicated by id.
  List<CombinationModifier> get grantedCombinationModifiers {
    return _grantedOfType<CombinationModifier>((grant) => grant.id);
  }

  /// Sum of every [MaxHpBonus] granted by unlocked nodes (nodes that grant
  /// a [Mutation] or [CombinationModifier] instead are skipped),
  /// deduplicated by id before summing.
  int get grantedMaxHpBonus {
    return _grantedOfType<MaxHpBonus>((grant) => grant.id)
        .fold<int>(0, (sum, bonus) => sum + bonus.bonus);
  }

  List<T> _grantedOfType<T>(String Function(T) idOf) {
    final seenIds = <String>{};
    final result = <T>[];
    for (final nodeId in unlockedNodeIds) {
      final grant = tree.nodeById(nodeId)!.grants;
      if (grant is T) {
        final typed = grant as T;
        if (seenIds.add(idOf(typed))) {
          result.add(typed);
        }
      }
    }
    return result;
  }
}
```

- [ ] **Step 10: Run test to verify it passes**

Run: `dart test test/skill_progress_test.dart`
Expected: PASS

- [ ] **Step 11: Write the failing test for `defaultSkillTree`'s Vitalidade node**

Add this test at the end of `packages/battle_engine/test/default_skill_tree_test.dart`, before the final closing `}`:

```dart
  test('unlocking Treino de Vitalidade grants 20 max HP', () {
    final progress =
        SkillProgress(defaultSkillTree).unlock('vitality_training');
    expect(progress.grantedMaxHpBonus, equals(20));
  });
```

- [ ] **Step 12: Run test to verify it fails**

Run: `dart test test/default_skill_tree_test.dart`
Expected: FAIL — no node with id `'vitality_training'` exists in `defaultSkillTree` yet.

- [ ] **Step 13: Add the node to `defaultSkillTree`**

Replace the full contents of `packages/battle_engine/lib/src/default_skill_tree.dart` with:

```dart
import 'combination_modifiers.dart';
import 'max_hp_bonuses.dart';
import 'mutations.dart';
import 'skill_node.dart';
import 'skill_tree.dart';

/// Example skill tree with four independent branches, granting the
/// built-in [Mutations], [CombinationModifiers] and [MaxHpBonuses].
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
]);
```

- [ ] **Step 14: Run test to verify it passes**

Run: `dart test test/default_skill_tree_test.dart`
Expected: PASS

- [ ] **Step 15: Run the whole package's analyzer and test suite**

Run: `dart analyze` then `dart test`
Expected: `No issues found!`, all tests pass.

- [ ] **Step 16: Commit**

```bash
git add packages/battle_engine/lib/src/max_hp_bonus.dart packages/battle_engine/lib/src/max_hp_bonuses.dart packages/battle_engine/lib/src/skill_progress.dart packages/battle_engine/lib/src/default_skill_tree.dart packages/battle_engine/lib/battle_engine.dart packages/battle_engine/test/max_hp_bonus_test.dart packages/battle_engine/test/skill_progress_test.dart packages/battle_engine/test/default_skill_tree_test.dart
git commit -m "feat(battle_engine): add MaxHpBonus and a Skill Tree node granting it"
```

---

## Task 7: `TrainingMatch` shows HP and the win condition

**Files:**
- Modify: `app/lib/game_domain/training_match.dart`
- Test: `app/test/game_domain/training_match_test.dart`

**Interfaces:**
- Consumes: `BattleState.start({playerAMaxHp, playerBMaxHp})`, `BattleState.hpOf`, `BattleState.winner`, `BattleState.withMaxHpIncreased`, `SkillProgress.grantedMaxHpBonus`, `MaxHpBonus` (Tasks 4 and 6).
- Produces: `TrainingMatch.playAMaxHp`, `.playerACurrentHp`, `.playerBMaxHp`, `.playerBCurrentHp` (int), `.winnerName` (`String?`), `.isOver` (bool). `unlockSkillForCurrentPlayer` now applies a `MaxHpBonus` live if the unlocked node grants one.

- [ ] **Step 1: Write the failing tests**

Add these tests to `app/test/game_domain/training_match_test.dart`, inside the existing top-level tests (not inside the `group('skill tree integration', ...)` — add a new group after it, right before the file's final closing `}`):

```dart
  group('HP and victory', () {
    test('both players start at 100/100 HP', () {
      final match = TrainingMatch();
      expect(match.playerAMaxHp, equals(100));
      expect(match.playerACurrentHp, equals(100));
      expect(match.playerBMaxHp, equals(100));
      expect(match.playerBCurrentHp, equals(100));
    });

    test('a triggered combination reduces the opponent\'s current HP', () {
      final match = TrainingMatch();
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
      final match = TrainingMatch();
      // 5 hits of 20 damage from Jogador A defeat Jogador B (100 HP).
      for (var i = 0; i < 4; i++) {
        match.playElementIds(['fire', 'wind']); // Jogador A
        match.playElementIds(['ice']); // Jogador B, no damage
      }
      match.playElementIds(['fire', 'wind']); // 5th hit: defeats Jogador B

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
      final match = TrainingMatch();
      match.playElementIds(['fire', 'wind']); // Jogador A hits B for 20
      // Now it's Jogador B's turn; they unlock Vitalidade for themselves.
      match.unlockSkillForCurrentPlayer('vitality_training');

      expect(match.playerBMaxHp, equals(120));
      expect(match.playerBCurrentHp, equals(100)); // 80 + 20, not 120
    });
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run (from `app/`): `flutter test test/game_domain/training_match_test.dart`
Expected: FAIL — `playerAMaxHp`, `playerACurrentHp`, `playerBMaxHp`, `playerBCurrentHp`, `winnerName` and `isOver` don't exist yet, and unlocking a `MaxHpBonus` node doesn't change HP yet.

- [ ] **Step 3: Implement**

Replace the full contents of `app/lib/game_domain/training_match.dart` with:

```dart
import 'package:battle_engine/battle_engine.dart';

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
/// Exposes only Flutter-friendly types, never a `battle_engine` type — ver
/// DECISION-011/017.
class TrainingMatch {
  static const _playerA = Combatant(id: 'a', name: 'Jogador A');
  static const _playerB = Combatant(id: 'b', name: 'Jogador B');
  static const _baseMaxHp = 100;

  final AbilityEngine _abilityEngine = AbilityEngine(
    TurnEngine(defaultCombinationBook),
  );

  BattleState _state = BattleState.start(
    playerA: _playerA,
    playerB: _playerB,
    playerAMaxHp: _baseMaxHp,
    playerBMaxHp: _baseMaxHp,
  );
  DiscoveryBook _discoveryBook = DiscoveryBook();

  SkillProgress _progressA = SkillProgress(defaultSkillTree);
  SkillProgress _progressB = SkillProgress(defaultSkillTree);

  String? _lastTriggeredCombinationName;
  List<String> _lastAppliedStatusNames = [];

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

  int get playerAMaxHp => _state.hpOf(_playerA).max;

  int get playerACurrentHp => _state.hpOf(_playerA).current;

  int get playerBMaxHp => _state.hpOf(_playerB).max;

  int get playerBCurrentHp => _state.hpOf(_playerB).current;

  /// Name of the winner, or null while the match is still ongoing.
  String? get winnerName => _state.winner?.name;

  bool get isOver => _state.winner != null;

  bool get _isPlayerATurn => _state.currentTurn == _playerA;

  SkillProgress get _currentProgress =>
      _isPlayerATurn ? _progressA : _progressB;

  Combatant get _currentCombatant => _isPlayerATurn ? _playerA : _playerB;

  /// Skill nodes the player whose turn it currently is could unlock right
  /// now (prerequisites met, not yet unlocked).
  List<SkillNodeOption> get availableSkillNodesForCurrentPlayer =>
      _currentProgress.availableNodes.map(skillNodeOptionFrom).toList();

  /// Names of the mutations/combination modifiers/HP bonuses the current
  /// player has already unlocked — shown so they can see their build
  /// taking shape.
  List<String> get unlockedGrantNamesForCurrentPlayer => [
        ..._currentProgress.grantedMutations.map((m) => m.name),
        ..._currentProgress.grantedCombinationModifiers.map((m) => m.name),
      ];

  /// Unlocks [nodeId] for whoever's turn it currently is. If the node
  /// grants a [MaxHpBonus], it's applied to that player's HP immediately
  /// (not deferred to their next action). Throws `StateError` if it can't
  /// be unlocked yet (see `SkillProgress.unlock`).
  void unlockSkillForCurrentPlayer(String nodeId) {
    final actor = _currentCombatant;
    final updated = _currentProgress.unlock(nodeId);
    if (_isPlayerATurn) {
      _progressA = updated;
    } else {
      _progressB = updated;
    }

    final grant = defaultSkillTree.nodeById(nodeId)!.grants;
    if (grant is MaxHpBonus) {
      _state = _state.withMaxHpIncreased(actor, grant.bonus);
    }
  }

  /// Plays the elements identified by [elementIds] (1 a 3) for whoever's
  /// turn it currently is, building an [Ability] on the fly from those
  /// elements plus everything the player has unlocked, wrapped in a
  /// [Build] (validated — always valid here, since mutations/modifiers
  /// come straight from what's granted). Throws `StateError` if the match
  /// is already over.
  void playElementIds(List<String> elementIds) {
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
        .map((status) => status.effect.name)
        .toList();
    if (result.triggeredCombination != null) {
      _discoveryBook = _discoveryBook.withDiscovered(
        result.triggeredCombination!,
      );
    }
  }
}
```

(Changes from the previous version: `_baseMaxHp` constant + passing it to `BattleState.start`; the four HP getters; `winnerName`/`isOver`; a new private `_currentCombatant` getter; `unlockSkillForCurrentPlayer` now captures `actor` up front and applies a `MaxHpBonus` live if that's what the node grants. `playElementIds` is unchanged.)

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/game_domain/training_match_test.dart`
Expected: PASS

- [ ] **Step 5: Run the whole app's analyzer and test suite**

Run: `flutter analyze` then `flutter test`
Expected: `No issues found!`, all tests pass (existing tests in this file and `training_screen_test.dart` don't touch HP/winner, so they're unaffected).

- [ ] **Step 6: Commit**

```bash
git add app/lib/game_domain/training_match.dart app/test/game_domain/training_match_test.dart
git commit -m "feat(app): TrainingMatch tracks HP and the win condition"
```

---

## Task 8: `TrainingScreen` shows HP and the end of the match

**Files:**
- Modify: `app/lib/ui/training_screen.dart`
- Test: `app/test/training_screen_test.dart`

**Interfaces:**
- Consumes: `TrainingMatch.playerAMaxHp/.playerACurrentHp/.playerBMaxHp/.playerBCurrentHp/.winnerName/.isOver` (Task 7).
- Produces: `TrainingScreen({super.key, TrainingMatch? initialMatch})` (constructor injection, for tests — defaults to a fresh `TrainingMatch()` exactly like before when omitted).

- [ ] **Step 1: Write the failing tests**

Replace the full contents of `app/test/training_screen_test.dart` with (this adds two new tests and one new import; the three existing tests are unchanged):

```dart
import 'package:app/game_domain/training_match.dart';
import 'package:app/main.dart';
import 'package:app/ui/training_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'selecting fire and wind then playing triggers Tempestade Ígnea and '
    'passes the turn to Jogador B',
    (WidgetTester tester) async {
      await tester.pumpWidget(const GameApp());

      await tester.tap(find.byIcon(Icons.school));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Vez de: Jogador A'), findsOneWidget);

      await tester.tap(find.text('🔥 Fogo'));
      await tester.pump();
      await tester.tap(find.text('🌪️ Vento'));
      await tester.pump();

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
    await tester.pumpWidget(const GameApp());

    await tester.tap(find.byIcon(Icons.school));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Jogar'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets(
    'unlocking Maestria da Brasa applies Queimadura to the opponent on the '
    'next action',
    (WidgetTester tester) async {
      await tester.pumpWidget(const GameApp());

      await tester.tap(find.byIcon(Icons.school));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.byIcon(Icons.auto_awesome));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Desbloquear').first);
      await tester.pump();

      await tester.tap(find.text('Fechar'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('🔥 Fogo'));
      await tester.pump();
      await tester.tap(find.text('Jogar'));
      await tester.pump();

      expect(
        find.text('Efeitos aplicados: Queimadura'),
        findsOneWidget,
      );
      expect(find.textContaining('Jogador B: Queimadura'), findsOneWidget);
    },
  );

  testWidgets(
    'shows the winner and a rematch button once the battle ends, hiding '
    'the play form',
    (WidgetTester tester) async {
      final match = TrainingMatch();
      for (var i = 0; i < 4; i++) {
        match.playElementIds(['fire', 'wind']); // Jogador A
        match.playElementIds(['ice']); // Jogador B, no damage
      }
      match.playElementIds(['fire', 'wind']); // 5th hit: defeats Jogador B
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
    final match = TrainingMatch();
    for (var i = 0; i < 4; i++) {
      match.playElementIds(['fire', 'wind']);
      match.playElementIds(['ice']);
    }
    match.playElementIds(['fire', 'wind']);

    await tester.pumpWidget(
      MaterialApp(home: TrainingScreen(initialMatch: match)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Nova partida'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Vez de: Jogador A'), findsOneWidget);
    expect(find.text('Jogar'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/training_screen_test.dart`
Expected: FAIL — `TrainingScreen` doesn't accept an `initialMatch` parameter yet, doesn't show HP, and doesn't show a game-over view.

- [ ] **Step 3: Implement**

Replace the full contents of `app/lib/ui/training_screen.dart` with:

```dart
import 'package:flutter/material.dart';

import '../game_domain/element_catalog.dart';
import '../game_domain/training_match.dart';

/// Modo treino: batalha local, offline, hotseat — os dois lados jogados no
/// mesmo aparelho. Sem backend, sem multiplayer, sem IA. Cada jogador pode
/// desbloquear habilidades da Skill Tree na própria vez; o que já
/// desbloqueou se aplica automaticamente em toda ação que jogar depois (e,
/// no caso de bônus de HP, imediatamente). A partida termina quando o HP
/// de alguém chega a 0.
class TrainingScreen extends StatefulWidget {
  const TrainingScreen({super.key, TrainingMatch? initialMatch})
      : _initialMatch = initialMatch;

  final TrainingMatch? _initialMatch;

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  late TrainingMatch _match = widget._initialMatch ?? TrainingMatch();
  final Set<String> _selectedIds = {};
  String? _error;

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
      try {
        _match.playElementIds(_selectedIds.toList());
        _selectedIds.clear();
      } on ArgumentError {
        _error = 'Jogada inválida.';
      }
    });
  }

  void _startNewMatch() {
    setState(() {
      _match = TrainingMatch();
      _selectedIds.clear();
      _error = null;
    });
  }

  void _openSkillTree() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final available = _match.availableSkillNodesForCurrentPlayer;
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Habilidades de ${_match.currentTurnName}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  if (available.isEmpty)
                    const Text('Nada novo para desbloquear agora.'),
                  for (final node in available)
                    ListTile(
                      title: Text('[${node.branch}] ${node.name}'),
                      subtitle: Text(node.description),
                      trailing: TextButton(
                        onPressed: () {
                          setState(() {
                            _match.unlockSkillForCurrentPlayer(node.id);
                          });
                          setSheetState(() {});
                        },
                        child: const Text('Desbloquear'),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Fechar'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modo Treino'),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'Habilidades',
            onPressed: _openSkillTree,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vez de: ${_match.currentTurnName}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Jogador A: ${_match.playerACurrentHp}/${_match.playerAMaxHp} HP',
            ),
            Text('Jogador A: ${_statusSummary(_match.playerAStatusNames)}'),
            Text(
              'Jogador B: ${_match.playerBCurrentHp}/${_match.playerBMaxHp} HP',
            ),
            Text('Jogador B: ${_statusSummary(_match.playerBStatusNames)}'),
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
            if (_match.activeFieldEffectNames.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Campo: ${_match.activeFieldEffectNames.join(", ")}',
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
    );
  }

  List<Widget> _buildGameOver(BuildContext context) {
    return [
      Text(
        'Fim de partida! Vencedor: ${_match.winnerName}',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 16),
      ElevatedButton(
        onPressed: _startNewMatch,
        child: const Text('Nova partida'),
      ),
    ];
  }

  List<Widget> _buildPlayForm(BuildContext context) {
    final elements = const ElementCatalog().all();

    return [
      Text(
        'Escolha de 1 a 3 elementos:',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final element in elements)
            FilterChip(
              label: Text('${element.symbol} ${element.name}'),
              selected: _selectedIds.contains(element.id),
              onSelected: (_) => _toggleElement(element.id),
            ),
        ],
      ),
      const SizedBox(height: 16),
      ElevatedButton(
        onPressed: _selectedIds.isEmpty ? null : _playTurn,
        child: const Text('Jogar'),
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

  String _statusSummary(List<String> statusNames) {
    return statusNames.isEmpty ? 'sem estados' : statusNames.join(', ');
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/training_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Run the whole app's analyzer and test suite**

Run: `flutter analyze` then `flutter test`
Expected: `No issues found!`, all tests pass.

- [ ] **Step 6: Commit**

```bash
git add app/lib/ui/training_screen.dart app/test/training_screen_test.dart
git commit -m "feat(app): TrainingScreen shows HP and the end of the match"
```

---

## Task 9: Full verification and documentation

No new code — this task confirms everything works together for real and updates the project's 4 context files per `CLAUDE.md`'s conventions.

- [ ] **Step 1: Run the full battle_engine suite**

Run (from `packages/battle_engine`): `dart analyze` then `dart test`
Expected: `No issues found!`, all tests pass (should be around 160+ tests total — the exact count doesn't matter, zero failures does).

- [ ] **Step 2: Run the full app suite**

Run (from `app`): `flutter analyze` then `flutter test`
Expected: `No issues found!`, all tests pass.

- [ ] **Step 3: Play a full match to a win in the real browser**

Start the app (`.claude/launch.json`'s `app-web` config, `flutter run -d web-server --web-port 5000`, or via the Browser pane's `preview_start` tool with name `app-web`), open it, navigate to Modo Treino, and play through:
1. Select 🔥 Fogo + 🌪️ Vento, tap Jogar — confirm Jogador B's HP drops from 100/100 to 80/100 and "Última combinação: Tempestade Ígnea" appears.
2. Play a few more rounds (any elements for Jogador B, repeat Fogo+Vento for Jogador A) until Jogador B's HP reaches 0.
3. Confirm the play form disappears, "Fim de partida! Vencedor: Jogador A" and a "Nova partida" button appear.
4. Tap "Nova partida" and confirm the match resets to "Vez de: Jogador A", 100/100 HP for both, and the play form is back.

Take a screenshot at the "Fim de partida" state as evidence.

- [ ] **Step 4: Update `ARCHITECTURE.md`**

Add a description of the new `HpPool`, `MaxHpBonus`/`MaxHpBonuses`, the damage/Escudo/DOT/win-condition resolution in `TurnEngine`, and the `TrainingMatch`/`TrainingScreen` HP + game-over UI, following the existing style of the "Battle Engine" and "App Flutter" sections (bullet per type/file, one or two sentences each). Do not restate content that didn't change.

- [ ] **Step 5: Update `TASKS.md`**

Move "Sistema de dano/HP/condição de vitória" from `NOW` to `DONE`, with a summary line matching the style of prior entries (what got built, test counts, what was verified running for real). Set the next `NOW` — since `NEXT`/`BACKLOG` are currently empty, leave `NOW` as "Nenhuma — aguardando definição da próxima tarefa" (same placeholder text used before this task started) unless the user has already named the next task by the time this runs.

- [ ] **Step 6: Update `DECISIONS.md`**

Add one entry recording: the final damage/HP numbers (100 base HP, 20/20/35 damage, Combustão 8×2, Vitalidade +20), the `playerAMaxHp`/`playerBMaxHp` default-100 refinement made during planning (and why — ~32 unrelated tests would've needed mechanical edits otherwise), the actor-wins-ties rule for simultaneous defeat, and the explicit reminder that `backend/src/battle-rules/` does **not** yet validate damage/HP/victory — extending that TypeScript mirror (DECISION-013/014) is a real prerequisite before Multiplayer's `POST /matches/:id/turns` can be trusted for a real match with stakes.

- [ ] **Step 7: Commit the documentation updates**

```bash
git add ARCHITECTURE.md TASKS.md DECISIONS.md
git commit -m "docs: record damage/HP/victory system in context files"
```
