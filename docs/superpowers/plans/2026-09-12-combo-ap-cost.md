# Custo de AP pra combinar elementos (Bloco 2a) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Elemento sozinho passa a ser sempre livre e causar 5 de dano direto; combinar 2 ou 3 elementos passa a exigir AP (recurso que acumula entre turnos, teto 5), em `battle_engine` (Dart) e no mirror TypeScript do backend, com o cliente Flutter (Treino e Multiplayer) mostrando o AP de cada jogador.

**Architecture:** Um `ApPool` novo (espelha `HpPool`) em `BattleState`/`BattleState` TS; `TurnEngine.playTurn`/`turn-engine.ts` regeneram, checam e gastam AP antes de resolver a ação, rejeitando (mesmo tipo de erro de "não é sua vez") quando insuficiente. O cliente propaga o AP até o HUD como uma fileira de pontinhos.

**Tech Stack:** Dart (`packages/battle_engine`), TypeScript/Node (`backend/src/battle-rules`), Flutter (`app/`).

**Spec:** [docs/superpowers/specs/2026-09-12-combo-ap-cost-design.md](../specs/2026-09-12-combo-ap-cost-design.md)

## Global Constraints

- Elemento sozinho: sempre 0 AP, sempre 5 de dano direto (bloqueável/consome Escudo, igual dano de combo).
- Combo de 2 elementos: 3 AP. Combo de 3 elementos: 5 AP (teto inteiro).
- AP começa em 0, regenera **+1 no início de cada turno próprio** (antes de checar o custo da própria ação), clampado no teto (5).
- Sem AP suficiente: ação inteira rejeitada (erro, sem gastar nada, sem passar o turno) — mesmo padrão de "não é sua vez"/"partida já acabou".
- `battle_engine` (Dart) e `backend/src/battle-rules/` (TypeScript) têm que ficar sincronizados — regra do próprio CLAUDE.md.
- **Achado importante escrevendo este plano**: o novo mecanismo quebra MUITOS testes existentes que hoje disparam combo como primeira ação (0 AP disponível) ou combam repetidamente sem intervalo — cada task abaixo inclui a correção desses testes, não só os novos. Onde um teste dependia de "combar toda vez", a correção usa ataques de elemento sozinho (grátis, 5 de dano) pra alcançar o mesmo resultado (ex: derrotar o oponente), já que isso não exercia AP mesmo antes — só testes que precisam mesmo de um COMBO ganham turnos de carga (`ap` semeado ou jogadas de elemento sozinho antes).
- `TrainingScreen._playTurn` precisa de um novo `on StateError` (mensagem em português) — a rejeição por AP não é `ArgumentError`.
- **Lição de teste (padrão desta sessão):** nunca `pumpAndSettle()` numa árvore com `AnimationController` repetindo; `tester.pump()` sem duração não flush `Future.delayed`/stream — sempre `tester.pump(const Duration(milliseconds: N))`.
- `flutter run -d web-server` nunca recompila sozinho ao recarregar — sempre `preview_stop` + `preview_start` completo.

---

## Arquivos afetados

**Novos:** `packages/battle_engine/lib/src/ap_pool.dart` + teste; `backend/src/battle-rules/ap-pool.ts` + teste.

**Modificados (produção):** `battle_state.dart`, `turn_engine.dart` (Dart); `types.ts`, `battle-state.ts`, `turn-engine.ts`, `parse.ts`, `validate-turn.ts` (TypeScript); `multiplayer_models.dart`, `multiplayer_match.dart`, `training_match.dart`, `battle_scene_view.dart` (game_domain); `battle_hud_widget.dart` (game_presentation); `training_screen.dart`, `multiplayer_battle_screen.dart` (ui).

**Modificados (só teste, corrigindo o que a mudança quebra):** `turn_engine_test.dart`, `battle_state_test.dart` (Dart); `turn-engine.test.ts`, `battle-state.test.ts`, `validate-turn.test.ts`, `ability-engine.test.ts`, `match-store.test.ts`, `matches.test.ts` (routes, TypeScript); `training_match_test.dart`, `multiplayer_match_test.dart`, `battle_scene_view_test.dart`, `battle_hud_widget_test.dart`, `training_screen_test.dart` (Flutter).

`DECISIONS.md`, `TASKS.md`.

---

### Task 1: `ApPool` (Dart)

**Files:**
- Create: `packages/battle_engine/lib/src/ap_pool.dart`
- Modify: `packages/battle_engine/lib/battle_engine.dart` (export)
- Test: `packages/battle_engine/test/ap_pool_test.dart`

**Interfaces:**
- Produces: `class ApPool { final int max; final int current; const ApPool({required max, required current}); bool canAfford(int amount); ApPool withRegenerated(); ApPool withSpent(int amount); }`

- [ ] **Step 1: Escrever o teste falho**

Criar `packages/battle_engine/test/ap_pool_test.dart`:

```dart
import 'package:battle_engine/battle_engine.dart';
import 'package:test/test.dart';

void main() {
  group('canAfford', () {
    test('true when current is greater than or equal to amount', () {
      const pool = ApPool(max: 5, current: 3);
      expect(pool.canAfford(3), isTrue);
      expect(pool.canAfford(2), isTrue);
    });

    test('false when current is less than amount', () {
      const pool = ApPool(max: 5, current: 2);
      expect(pool.canAfford(3), isFalse);
    });
  });

  group('withRegenerated', () {
    test('increments current by 1', () {
      const pool = ApPool(max: 5, current: 2);
      expect(pool.withRegenerated().current, equals(3));
    });

    test('clamps at max', () {
      const pool = ApPool(max: 5, current: 5);
      expect(pool.withRegenerated().current, equals(5));
    });
  });

  group('withSpent', () {
    test('subtracts amount from current', () {
      const pool = ApPool(max: 5, current: 4);
      expect(pool.withSpent(3).current, equals(1));
    });

    test('throws for a negative amount', () {
      const pool = ApPool(max: 5, current: 4);
      expect(() => pool.withSpent(-1), throwsArgumentError);
    });

    test('throws when amount exceeds current', () {
      const pool = ApPool(max: 5, current: 2);
      expect(() => pool.withSpent(3), throwsArgumentError);
    });
  });
}
```

- [ ] **Step 2: Rodar o teste e confirmar que falha**

Run: `cd packages/battle_engine && dart test test/ap_pool_test.dart`
Expected: FAIL — `ap_pool.dart` ainda não existe.

- [ ] **Step 3: Implementar `ApPool`**

Criar `packages/battle_engine/lib/src/ap_pool.dart`:

```dart
/// An immutable AP (action point) pool: how much a combatant can hold
/// (`max`) and how much they currently have (`current`). Used to gate
/// combining 2-3 elements in one turn — see [TurnEngine.playTurn].
/// `current` never goes below 0 or above `max`.
class ApPool {
  final int max;
  final int current;

  const ApPool({required this.max, required this.current});

  bool canAfford(int amount) => current >= amount;

  /// Returns a new pool with `current` incremented by 1, clamped at `max`.
  ApPool withRegenerated() {
    final next = current + 1;
    return ApPool(max: max, current: next > max ? max : next);
  }

  /// Returns a new pool with `amount` subtracted from `current`. Callers
  /// must check [canAfford] first — throws if `amount` is negative or
  /// exceeds `current`.
  ApPool withSpent(int amount) {
    if (amount < 0) {
      throw ArgumentError.value(amount, 'amount', 'must not be negative');
    }
    if (amount > current) {
      throw ArgumentError.value(amount, 'amount', 'exceeds current AP');
    }
    return ApPool(max: max, current: current - amount);
  }
}
```

Em `packages/battle_engine/lib/battle_engine.dart`, adicionar logo depois de `export 'src/hp_pool.dart';`:

```dart
export 'src/hp_pool.dart';
export 'src/ap_pool.dart';
```

- [ ] **Step 4: Rodar o teste e confirmar que passa**

Run: `cd packages/battle_engine && dart test test/ap_pool_test.dart`
Expected: PASS (7 testes).

- [ ] **Step 5: Commit**

```bash
git add packages/battle_engine/lib/src/ap_pool.dart packages/battle_engine/lib/battle_engine.dart packages/battle_engine/test/ap_pool_test.dart
git commit -m "$(cat <<'EOF'
Adiciona ApPool (Bloco 2a, custo de AP pra combos)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: `BattleState` ganha `ap` (Dart)

**Files:**
- Modify: `packages/battle_engine/lib/src/battle_state.dart`
- Test: `packages/battle_engine/test/battle_state_test.dart`

**Interfaces:**
- Consumes: `ApPool` (Task 1).
- Produces: `BattleState.ap: Map<Combatant, ApPool>`; `BattleState.start({..., Map<Combatant, ApPool>? ap})`; `BattleState.copyWith({..., Map<Combatant, ApPool>? ap})`; `ApPool apOf(Combatant)`; `BattleState withApRegenerated(Combatant)`; `BattleState withApSpent(Combatant, int amount)`.

- [ ] **Step 1: Escrever os testes falhos**

Em `packages/battle_engine/test/battle_state_test.dart`, adicionar um novo `group` ao final do `main()` (antes do `}` de fechamento), depois do `group('BattleState HP', ...)`:

```dart
  group('BattleState AP', () {
    test('start defaults both players to 5 max, 0 current AP', () {
      final state = BattleState.start(playerA: playerA, playerB: playerB);
      expect(state.apOf(playerA).max, equals(5));
      expect(state.apOf(playerA).current, equals(0));
      expect(state.apOf(playerB).max, equals(5));
      expect(state.apOf(playerB).current, equals(0));
    });

    test('start accepts a seeded AP override, for tests that need a '
        'combo affordable right away', () {
      final state = BattleState.start(
        playerA: playerA,
        playerB: playerB,
        ap: {playerA: const ApPool(max: 5, current: 3)},
      );
      expect(state.apOf(playerA).current, equals(3));
      expect(state.apOf(playerB).current, equals(0));
    });

    test('apOf throws for a combatant outside the battle', () {
      final state = BattleState.start(playerA: playerA, playerB: playerB);
      const stranger = Combatant(id: 'c', name: 'Carla');
      expect(() => state.apOf(stranger), throwsArgumentError);
    });

    test('withApRegenerated increments only the target\'s AP', () {
      final state = BattleState.start(playerA: playerA, playerB: playerB);
      final next = state.withApRegenerated(playerA);

      expect(next.apOf(playerA).current, equals(1));
      expect(next.apOf(playerB).current, equals(0));
    });

    test('withApSpent decrements only the target\'s AP', () {
      final state = BattleState.start(
        playerA: playerA,
        playerB: playerB,
        ap: {playerA: const ApPool(max: 5, current: 3)},
      );
      final next = state.withApSpent(playerA, 3);

      expect(next.apOf(playerA).current, equals(0));
      expect(next.apOf(playerB).current, equals(0));
    });

    test('copyWith preserves ap when not specified', () {
      final state = BattleState.start(
        playerA: playerA,
        playerB: playerB,
        ap: {playerA: const ApPool(max: 5, current: 3)},
      );
      final next = state.copyWith(currentTurn: playerB);

      expect(next.apOf(playerA).current, equals(3));
    });
  });
```

- [ ] **Step 2: Rodar os testes e confirmar que falham**

Run: `cd packages/battle_engine && dart test test/battle_state_test.dart`
Expected: os testes antigos PASS, o novo grupo FAIL — `ap`/`apOf`/`withApRegenerated`/`withApSpent` não existem ainda.

- [ ] **Step 3: Implementar `ap` em `BattleState`**

Em `packages/battle_engine/lib/src/battle_state.dart`, adicionar o import no topo:

```dart
import 'active_status.dart';
import 'ap_pool.dart';
import 'combatant.dart';
import 'field_effect.dart';
import 'hp_pool.dart';
import 'status_effect.dart';
```

Adicionar o campo `ap` (logo depois de `hp`), semeá-lo no construtor (logo depois do bloco que semeia `hp`), aceitá-lo em `start` e `copyWith`, e adicionar os três métodos novos (logo depois de `withMaxHpIncreased`):

```dart
  final Combatant playerA;
  final Combatant playerB;
  final Combatant currentTurn;
  final List<FieldEffect> activeFieldEffects;
  final Map<Combatant, List<ActiveStatus>> combatantStatuses;
  final Map<Combatant, HpPool> hp;
  final Map<Combatant, ApPool> ap;
  final Combatant? winner;

  BattleState({
    required this.playerA,
    required this.playerB,
    required this.currentTurn,
    List<FieldEffect> activeFieldEffects = const [],
    Map<Combatant, List<ActiveStatus>>? combatantStatuses,
    Map<Combatant, HpPool>? hp,
    Map<Combatant, ApPool>? ap,
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
        }),
        ap = Map<Combatant, ApPool>.unmodifiable({
          playerA: ap?[playerA] ?? const ApPool(max: 5, current: 0),
          playerB: ap?[playerB] ?? const ApPool(max: 5, current: 0),
        }) {
    if (playerA == playerB) {
      throw ArgumentError('playerA and playerB must be distinct combatants');
    }
    if (currentTurn != playerA && currentTurn != playerB) {
      throw ArgumentError('currentTurn must be playerA or playerB');
    }
  }

  factory BattleState.start({
    required Combatant playerA,
    required Combatant playerB,
    int playerAMaxHp = 100,
    int playerBMaxHp = 100,
    Map<Combatant, ApPool>? ap,
  }) {
    return BattleState(
      playerA: playerA,
      playerB: playerB,
      currentTurn: playerA,
      hp: {
        playerA: HpPool(max: playerAMaxHp, current: playerAMaxHp),
        playerB: HpPool(max: playerBMaxHp, current: playerBMaxHp),
      },
      ap: ap,
    );
  }

  BattleState copyWith({
    Combatant? currentTurn,
    List<FieldEffect>? activeFieldEffects,
    Map<Combatant, List<ActiveStatus>>? combatantStatuses,
    Map<Combatant, HpPool>? hp,
    Map<Combatant, ApPool>? ap,
    Combatant? winner,
  }) {
    return BattleState(
      playerA: playerA,
      playerB: playerB,
      currentTurn: currentTurn ?? this.currentTurn,
      activeFieldEffects: activeFieldEffects ?? this.activeFieldEffects,
      combatantStatuses: combatantStatuses ?? this.combatantStatuses,
      hp: hp ?? this.hp,
      ap: ap ?? this.ap,
      winner: winner ?? this.winner,
    );
  }
```

E os três métodos novos, logo depois de `withMaxHpIncreased`:

```dart
  /// AP pool of [combatant].
  ApPool apOf(Combatant combatant) {
    _requireParticipant(combatant);
    return ap[combatant]!;
  }

  /// Returns a new state with [combatant]'s AP incremented by 1 (clamped
  /// at their max) — happens at the start of their own turn, before
  /// [TurnEngine.playTurn] checks whether they can afford a combination.
  BattleState withApRegenerated(Combatant combatant) {
    _requireParticipant(combatant);
    final updated = Map<Combatant, ApPool>.from(ap)
      ..[combatant] = apOf(combatant).withRegenerated();
    return copyWith(ap: updated);
  }

  /// Returns a new state with [amount] of AP subtracted from
  /// [combatant]'s pool.
  BattleState withApSpent(Combatant combatant, int amount) {
    _requireParticipant(combatant);
    final updated = Map<Combatant, ApPool>.from(ap)
      ..[combatant] = apOf(combatant).withSpent(amount);
    return copyWith(ap: updated);
  }
```

- [ ] **Step 4: Rodar os testes e confirmar que passam**

Run: `cd packages/battle_engine && dart test test/battle_state_test.dart`
Expected: PASS (todos os testes do arquivo, incluindo o grupo novo).

- [ ] **Step 5: Rodar a suíte inteira do pacote**

Run: `cd packages/battle_engine && dart analyze && dart test`
Expected: `No issues found!`, todos os testes PASS (nenhum outro arquivo usa `BattleState` de um jeito que quebre com um campo novo opcional).

- [ ] **Step 6: Commit**

```bash
git add packages/battle_engine/lib/src/battle_state.dart packages/battle_engine/test/battle_state_test.dart
git commit -m "$(cat <<'EOF'
BattleState ganha AP por jogador (Bloco 2a)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: `TurnEngine.playTurn` gasta AP e aplica dano básico (Dart)

**Files:**
- Modify: `packages/battle_engine/lib/src/turn_engine.dart`
- Test: `packages/battle_engine/test/turn_engine_test.dart` (reescrita completa — a mudança afeta quase todo teste do arquivo)

**Interfaces:**
- Consumes: `ApPool`/`BattleState.apOf`/`withApRegenerated`/`withApSpent` (Tasks 1-2).

- [ ] **Step 1: Substituir `turn_engine_test.dart` por inteiro (passos 1-2 do TDD combinados: primeiro roda RED contra a implementação antiga, depois GREEN contra a nova)**

Substituir todo o conteúdo de `packages/battle_engine/test/turn_engine_test.dart` por:

```dart
import 'package:battle_engine/battle_engine.dart';
import 'package:test/test.dart';

void main() {
  const playerA = Combatant(id: 'a', name: 'Ana');
  const playerB = Combatant(id: 'b', name: 'Beto');
  final engine = TurnEngine(defaultCombinationBook);

  group('TurnAction', () {
    test('throws if no elements are played', () {
      expect(
        () => TurnAction(actor: playerA, elements: const []),
        throwsArgumentError,
      );
    });
  });

  group('TurnEngine.playTurn', () {
    test('rejects an action from a combatant whose turn it is not', () {
      final state = BattleState.start(playerA: playerA, playerB: playerB);
      final action = TurnAction(actor: playerB, elements: [Elements.fire]);

      expect(() => engine.playTurn(state, action), throwsStateError);
    });

    test('passes the turn to the opponent after a valid action', () {
      final state = BattleState.start(playerA: playerA, playerB: playerB);
      final action = TurnAction(actor: playerA, elements: [Elements.fire]);

      final result = engine.playTurn(state, action);

      expect(result.state.currentTurn, equals(playerB));
    });

    test('a single played element never triggers a combination', () {
      final state = BattleState.start(playerA: playerA, playerB: playerB);
      final action = TurnAction(actor: playerA, elements: [Elements.fire]);

      final result = engine.playTurn(state, action);

      expect(result.triggeredCombination, isNull);
      expect(result.state.activeFieldEffects, isEmpty);
    });

    test('playing a known 2-element combination adds it to the field', () {
      final state = BattleState.start(
        playerA: playerA,
        playerB: playerB,
        ap: {playerA: const ApPool(max: 5, current: 3)},
      );
      final action = TurnAction(
        actor: playerA,
        elements: [Elements.fire, Elements.wind],
      );

      final result = engine.playTurn(state, action);

      expect(result.triggeredCombination?.resultId, equals('ignited_storm'));
      expect(result.state.activeFieldEffects, hasLength(1));
      expect(
        result.state.activeFieldEffects.first.id,
        equals('ignited_storm'),
      );
    });

    test('playing an unknown combination advances the turn without adding '
        'a field effect', () {
      final state = BattleState.start(
        playerA: playerA,
        playerB: playerB,
        ap: {playerA: const ApPool(max: 5, current: 3)},
      );
      final action = TurnAction(
        actor: playerA,
        elements: [Elements.ice, Elements.shadow],
      );

      final result = engine.playTurn(state, action);

      expect(result.triggeredCombination, isNull);
      expect(result.state.activeFieldEffects, isEmpty);
      expect(result.state.currentTurn, equals(playerB));
    });

    test('turns alternate across multiple plays', () {
      var state = BattleState.start(playerA: playerA, playerB: playerB);

      state = engine
          .playTurn(state, TurnAction(actor: playerA, elements: [Elements.fire]))
          .state;
      expect(state.currentTurn, equals(playerB));

      state = engine
          .playTurn(state, TurnAction(actor: playerB, elements: [Elements.water]))
          .state;
      expect(state.currentTurn, equals(playerA));
    });

    test('field effects accumulate across turns', () {
      var state = BattleState.start(
        playerA: playerA,
        playerB: playerB,
        ap: {
          playerA: const ApPool(max: 5, current: 3),
          playerB: const ApPool(max: 5, current: 3),
        },
      );

      state = engine
          .playTurn(
            state,
            TurnAction(
              actor: playerA,
              elements: [Elements.fire, Elements.wind],
            ),
          )
          .state;

      state = engine
          .playTurn(
            state,
            TurnAction(
              actor: playerB,
              elements: [Elements.water, Elements.lightning],
            ),
          )
          .state;

      expect(state.activeFieldEffects, hasLength(2));
    });

    test('applies combinationModifiers to a triggered combination\'s '
        'field effect before adding it to the field', () {
      final state = BattleState.start(
        playerA: playerA,
        playerB: playerB,
        ap: {playerA: const ApPool(max: 5, current: 3)},
      );
      final action = TurnAction(
        actor: playerA,
        elements: [Elements.fire, Elements.wind],
      );

      final result = engine.playTurn(
        state,
        action,
        combinationModifiers: [CombinationModifiers.propagation],
      );

      expect(result.state.activeFieldEffects.single.area, equals(3));
    });

    test('combinationModifiers apply in order', () {
      final state = BattleState.start(
        playerA: playerA,
        playerB: playerB,
        ap: {playerA: const ApPool(max: 5, current: 5)},
      );
      final action = TurnAction(
        actor: playerA,
        elements: [Elements.earth, Elements.fire, Elements.water],
      );

      final result = engine.playTurn(
        state,
        action,
        combinationModifiers: [
          CombinationModifiers.propagation,
          CombinationModifiers.propagation,
        ],
      );

      expect(result.state.activeFieldEffects.single.area, equals(5));
    });

    test('combinationModifiers are ignored when no combination triggers',
        () {
      final state = BattleState.start(playerA: playerA, playerB: playerB);
      final action = TurnAction(actor: playerA, elements: [Elements.fire]);

      final result = engine.playTurn(
        state,
        action,
        combinationModifiers: [CombinationModifiers.propagation],
      );

      expect(result.state.activeFieldEffects, isEmpty);
    });

    test('with no combinationModifiers the combination result is '
        'unmodified', () {
      final state = BattleState.start(
        playerA: playerA,
        playerB: playerB,
        ap: {playerA: const ApPool(max: 5, current: 3)},
      );
      final action = TurnAction(
        actor: playerA,
        elements: [Elements.fire, Elements.wind],
      );

      final result = engine.playTurn(state, action);

      expect(result.state.activeFieldEffects.single.area, equals(1));
    });

    test('a known 2-element combination deals 20 damage to the opponent',
        () {
      final state = BattleState.start(
        playerA: playerA,
        playerB: playerB,
        ap: {playerA: const ApPool(max: 5, current: 3)},
      );
      final action = TurnAction(
        actor: playerA,
        elements: [Elements.fire, Elements.wind],
      );

      final result = engine.playTurn(state, action);

      expect(result.state.hpOf(playerB).current, equals(80));
      expect(result.state.hpOf(playerA).current, equals(100));
    });

    test('the 3-element combination deals 35 damage', () {
      final state = BattleState.start(
        playerA: playerA,
        playerB: playerB,
        ap: {playerA: const ApPool(max: 5, current: 5)},
      );
      final action = TurnAction(
        actor: playerA,
        elements: [Elements.earth, Elements.fire, Elements.water],
      );

      final result = engine.playTurn(state, action);

      expect(result.state.hpOf(playerB).current, equals(65));
    });

    test('a single element deals 5 basic damage; an unknown combination '
        'deals none', () {
      final state = BattleState.start(
        playerA: playerA,
        playerB: playerB,
        ap: {playerB: const ApPool(max: 5, current: 3)},
      );

      final afterSingle = engine
          .playTurn(
            state,
            TurnAction(actor: playerA, elements: [Elements.fire]),
          )
          .state;
      expect(afterSingle.hpOf(playerB).current, equals(95));

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
      final state = BattleState.start(
        playerA: playerA,
        playerB: playerB,
        ap: {playerA: const ApPool(max: 5, current: 3)},
      ).withStatusApplied(playerB, ActiveStatus(effect: StatusEffects.shield));
      final action = TurnAction(
        actor: playerA,
        elements: [Elements.fire, Elements.wind],
      );

      final result = engine.playTurn(state, action);

      expect(result.state.hpOf(playerB).current, equals(100));
      expect(result.state.hasStatus(playerB, StatusEffects.shield), isFalse);
    });

    test('Shield does not block a second hit after being consumed', () {
      var state = BattleState.start(
        playerA: playerA,
        playerB: playerB,
        ap: {playerA: const ApPool(max: 5, current: 4)},
      ).withStatusApplied(playerB, ActiveStatus(effect: StatusEffects.shield));

      state = engine
          .playTurn(
            state,
            TurnAction(actor: playerA, elements: [Elements.fire, Elements.wind]),
          )
          .state; // blocked, shield consumed (4 seeded + 1 regen - 3 spent = 2 left)
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
          .state; // 2 + 1 regen = 3, affordable again — not blocked this time

      expect(state.hpOf(playerB).current, equals(80));
    });

    test('a status with damagePerTick damages its owner at the end of '
        'every playTurn call, including the tick that expires it — on top '
        'of the actor\'s own basic damage', () {
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
      // playerB: 100 - 5 (a's basic damage) - 8 (first DOT tick) = 87
      expect(state.hpOf(playerB).current, equals(87));

      state = engine
          .playTurn(state, TurnAction(actor: playerB, elements: [Elements.water]))
          .state;
      // playerA: 100 - 5 (b's basic damage) = 95
      // playerB: 87 - 8 (second DOT tick, expires) = 79
      expect(state.hpOf(playerA).current, equals(95));
      expect(state.hpOf(playerB).current, equals(79));
      expect(state.hasStatus(playerB, StatusEffects.burn), isFalse);
    });

    test('combo damage can set a winner', () {
      final state = BattleState.start(
        playerA: playerA,
        playerB: playerB,
        playerBMaxHp: 15,
        ap: {playerA: const ApPool(max: 5, current: 3)},
      );
      final result = engine.playTurn(
        state,
        TurnAction(actor: playerA, elements: [Elements.fire, Elements.wind]),
      );

      expect(result.state.hpOf(playerB).isDefeated, isTrue);
      expect(result.state.winner, equals(playerA));
    });

    test('DOT damage alone can set a winner', () {
      // playerBMaxHp is 10, not 5: a's basic damage (5) alone must not be
      // enough to defeat them — only the DOT tick (8) on top of it should.
      var state = BattleState.start(
        playerA: playerA,
        playerB: playerB,
        playerBMaxHp: 10,
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
      // Both start at 8 HP (not 5): a's basic damage (5) to b alone must
      // not decide the winner ahead of the DOT tick this test is about —
      // it isolates the tie strictly to DOT tick ordering.
      final state = BattleState.start(
        playerA: playerA,
        playerB: playerB,
        playerAMaxHp: 8,
        playerBMaxHp: 8,
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
        ap: {playerA: const ApPool(max: 5, current: 3)},
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

    test('ends the match after enough basic (single-element) hits, with '
        'no AP involved', () {
      // 5 basic damage per hit — 20 hits defeat 100 HP. Actor A acts
      // first each round, so their 20th hit lands before B's 20th.
      var state = BattleState.start(playerA: playerA, playerB: playerB);
      for (var i = 0; i < 19; i++) {
        state = engine
            .playTurn(state, TurnAction(actor: playerA, elements: [Elements.fire]))
            .state;
        state = engine
            .playTurn(state, TurnAction(actor: playerB, elements: [Elements.ice]))
            .state;
      }
      final result = engine.playTurn(
        state,
        TurnAction(actor: playerA, elements: [Elements.fire]),
      );

      expect(result.state.hpOf(playerB).isDefeated, isTrue);
      expect(result.state.winner, equals(playerA));
    });
  });

  group('AP cost for combining elements', () {
    test('regenerates 1 AP for the actor at the start of their turn', () {
      final state = BattleState.start(playerA: playerA, playerB: playerB);
      final action = TurnAction(actor: playerA, elements: [Elements.fire]);

      final result = engine.playTurn(state, action);

      expect(result.state.apOf(playerA).current, equals(1));
      expect(result.state.apOf(playerB).current, equals(0));
    });

    test('AP regeneration is clamped at max', () {
      final state = BattleState.start(
        playerA: playerA,
        playerB: playerB,
        ap: {playerA: const ApPool(max: 5, current: 5)},
      );
      final action = TurnAction(actor: playerA, elements: [Elements.fire]);

      final result = engine.playTurn(state, action);

      expect(result.state.apOf(playerA).current, equals(5));
    });

    test('rejects a 2-element combination without enough AP', () {
      final state = BattleState.start(playerA: playerA, playerB: playerB);
      final action = TurnAction(
        actor: playerA,
        elements: [Elements.fire, Elements.wind],
      );

      expect(() => engine.playTurn(state, action), throwsStateError);
    });

    test('rejects a 3-element combination that only affords a 2-element '
        'one', () {
      final state = BattleState.start(
        playerA: playerA,
        playerB: playerB,
        ap: {playerA: const ApPool(max: 5, current: 3)},
      );
      final action = TurnAction(
        actor: playerA,
        elements: [Elements.earth, Elements.fire, Elements.water],
      );

      expect(() => engine.playTurn(state, action), throwsStateError);
    });

    test('spends 3 AP on a successful 2-element combination', () {
      final state = BattleState.start(
        playerA: playerA,
        playerB: playerB,
        ap: {playerA: const ApPool(max: 5, current: 3)},
      );
      final action = TurnAction(
        actor: playerA,
        elements: [Elements.fire, Elements.wind],
      );

      final result = engine.playTurn(state, action);

      // seeded 3 + 1 regen = 4, minus 3 spent = 1
      expect(result.state.apOf(playerA).current, equals(1));
    });

    test('spends all 5 AP on a successful 3-element combination', () {
      final state = BattleState.start(
        playerA: playerA,
        playerB: playerB,
        ap: {playerA: const ApPool(max: 5, current: 5)},
      );
      final action = TurnAction(
        actor: playerA,
        elements: [Elements.earth, Elements.fire, Elements.water],
      );

      final result = engine.playTurn(state, action);

      expect(result.state.apOf(playerA).current, equals(0));
    });
  });
}
```

- [ ] **Step 2: Rodar os testes e confirmar as falhas esperadas**

Run: `cd packages/battle_engine && dart test test/turn_engine_test.dart`
Expected: FAIL em massa — nenhum combo custa AP ainda, elemento sozinho não causa dano ainda, `apOf` não existe no resultado.

- [ ] **Step 3: Implementar a mudança em `TurnEngine.playTurn`**

Em `packages/battle_engine/lib/src/turn_engine.dart`, substituir o conteúdo inteiro do arquivo por:

```dart
import 'battle_state.dart';
import 'combatant.dart';
import 'combination_book.dart';
import 'combination_modifier.dart';
import 'status_effects.dart';
import 'turn_action.dart';
import 'turn_result.dart';

/// Resolves one turn at a time. Pure logic: given a state and an action,
/// produces the next state — including AP (regen, cost, rejection),
/// combination damage, basic (single-element) damage, Escudo blocking,
/// status damage-over-time ticks, and the win condition. Does not know
/// about Skill Tree/Build (mutations/combination modifiers are passed in
/// by the caller) or about persistence/the backend.
class TurnEngine {
  final CombinationBook combinationBook;

  static const _basicDamage = 5;
  static const _comboApCost = {2: 3, 3: 5};

  const TurnEngine(this.combinationBook);

  /// Resolves [action] against [state]:
  /// - rejects it if the battle already has a [BattleState.winner]
  /// - rejects it if it's not [TurnAction.actor]'s turn
  /// - regenerates 1 AP for [TurnAction.actor] (clamped at their max)
  /// - if 2 or 3 elements were played, rejects the whole action (no AP
  ///   spent, no damage, turn doesn't pass) if the actor can't afford it
  ///   (2 elements cost 3 AP, 3 elements cost 5), otherwise spends it
  /// - resolves a combination from the played elements, if 2 or 3 were
  ///   played
  /// - runs the triggered combination's [FieldEffect] through
  ///   [combinationModifiers], in order (bigger area, shorter duration...)
  /// - adds the (possibly modified) effect to the field
  /// - if it deals damage, applies it to the opponent — unless the
  ///   opponent has an active Escudo, which blocks the hit entirely and
  ///   is then consumed
  /// - a single played element never resolves a combination — instead it
  ///   always deals a flat basic damage to the opponent (same Escudo
  ///   blocking rule)
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

    var nextState = state.withApRegenerated(action.actor);

    final elementCount = action.elements.length;
    if (elementCount >= 2) {
      final cost = _comboApCost[elementCount]!;
      if (!nextState.apOf(action.actor).canAfford(cost)) {
        throw StateError(
          'Not enough AP for a $elementCount-element combination',
        );
      }
      nextState = nextState.withApSpent(action.actor, cost);
    }

    final combination = elementCount >= 2
        ? combinationBook.resolve(action.elements)
        : null;

    final opponent = nextState.opponentOf(action.actor);
    nextState = nextState.copyWith(currentTurn: opponent);

    if (combination != null) {
      var fieldEffect = combination.result;
      for (final modifier in combinationModifiers) {
        fieldEffect = modifier.apply(fieldEffect);
      }
      nextState = nextState.withFieldEffect(fieldEffect);
      nextState = _applyDamage(nextState, opponent, fieldEffect.damage);
    } else if (elementCount == 1) {
      nextState = _applyDamage(nextState, opponent, _basicDamage);
    }

    nextState = _tickStatusDamage(nextState, action.actor);

    return TurnResult(state: nextState, triggeredCombination: combination);
  }

  BattleState _applyDamage(
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

- [ ] **Step 4: Rodar os testes e confirmar que passam**

Run: `cd packages/battle_engine && dart test test/turn_engine_test.dart`
Expected: PASS (todos os testes do arquivo).

- [ ] **Step 5: Rodar a suíte inteira do pacote**

Run: `cd packages/battle_engine && dart analyze && dart test`
Expected: `No issues found!`, todos os testes PASS — inclusive `ability_engine_test.dart`/outros arquivos que usam `TurnEngine`/`AbilityEngine` indiretamente. Se algum outro teste falhar por causa de AP insuficiente, aplique a mesma correção (semear `ap:` ou trocar por elemento sozinho) diretamente nele antes de prosseguir.

- [ ] **Step 6: Commit**

```bash
git add packages/battle_engine/lib/src/turn_engine.dart packages/battle_engine/test/turn_engine_test.dart
git commit -m "$(cat <<'EOF'
TurnEngine gasta AP em combos e aplica dano básico (Bloco 2a)

Combinar 2-3 elementos agora custa AP (3/5); elemento sozinho é sempre
grátis e passa a causar 5 de dano direto. Reescreve turn_engine_test.dart
— a mudança quebra quase todo teste existente que combava como
primeira ação ou repetidamente sem intervalo.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: `ApPool` mirror em TypeScript

**Files:**
- Create: `backend/src/battle-rules/ap-pool.ts`
- Modify: `backend/src/battle-rules/types.ts`
- Test: `backend/test/battle-rules/ap-pool.test.ts`

**Interfaces:**
- Produces: `interface ApPool { readonly max: number; readonly current: number; }`; `canAfford(pool, amount)`, `withRegenerated(pool)`, `withSpent(pool, amount)`.

- [ ] **Step 1: Escrever o teste falho**

Criar `backend/test/battle-rules/ap-pool.test.ts`:

```ts
import { test } from "node:test";
import assert from "node:assert/strict";

import { canAfford, withRegenerated, withSpent } from "../../src/battle-rules/ap-pool.js";

test("canAfford is true when current is greater than or equal to amount", () => {
  assert.equal(canAfford({ max: 5, current: 3 }, 3), true);
  assert.equal(canAfford({ max: 5, current: 3 }, 2), true);
});

test("canAfford is false when current is less than amount", () => {
  assert.equal(canAfford({ max: 5, current: 2 }, 3), false);
});

test("withRegenerated increments current by 1", () => {
  const pool = withRegenerated({ max: 5, current: 2 });
  assert.deepEqual(pool, { max: 5, current: 3 });
});

test("withRegenerated clamps at max", () => {
  const pool = withRegenerated({ max: 5, current: 5 });
  assert.deepEqual(pool, { max: 5, current: 5 });
});

test("withSpent subtracts amount from current", () => {
  const pool = withSpent({ max: 5, current: 4 }, 3);
  assert.deepEqual(pool, { max: 5, current: 1 });
});

test("withSpent throws for a negative amount", () => {
  assert.throws(() => withSpent({ max: 5, current: 4 }, -1));
});

test("withSpent throws when amount exceeds current", () => {
  assert.throws(() => withSpent({ max: 5, current: 2 }, 3));
});
```

- [ ] **Step 2: Rodar o teste e confirmar que falha**

Run: `cd backend && npx tsx --test test/battle-rules/ap-pool.test.ts`
Expected: FAIL — `ap-pool.ts` ainda não existe.

- [ ] **Step 3: Implementar `ApPool` e adicionar em `types.ts`**

Criar `backend/src/battle-rules/ap-pool.ts`:

```ts
import type { ApPool } from "./types.js";

/** Mirrors ApPool in battle_engine (Dart) — `current` never goes below 0
 * or above `max`. Used to gate combining 2-3 elements in one turn. */
export function canAfford(pool: ApPool, amount: number): boolean {
  return pool.current >= amount;
}

/** Increments `current` by 1, clamped at `max`. */
export function withRegenerated(pool: ApPool): ApPool {
  return { max: pool.max, current: Math.min(pool.max, pool.current + 1) };
}

/** Subtracts `amount` from `current`. Callers must check `canAfford`
 * first — throws if `amount` is negative or exceeds `current`. */
export function withSpent(pool: ApPool, amount: number): ApPool {
  if (amount < 0) {
    throw new Error("amount must not be negative");
  }
  if (amount > pool.current) {
    throw new Error("amount exceeds current AP");
  }
  return { max: pool.max, current: pool.current - amount };
}
```

Em `backend/src/battle-rules/types.ts`, adicionar logo depois da interface `HpPool`:

```ts
/** Mirrors HpPool in battle_engine (Dart). */
export interface HpPool {
  readonly max: number;
  readonly current: number;
}

/** Mirrors ApPool in battle_engine (Dart) — action points, gates
 * combining 2-3 elements in one turn (see turn-engine.ts). */
export interface ApPool {
  readonly max: number;
  readonly current: number;
}
```

- [ ] **Step 4: Rodar o teste e confirmar que passa**

Run: `cd backend && npx tsx --test test/battle-rules/ap-pool.test.ts`
Expected: PASS (7 testes).

- [ ] **Step 5: Commit**

```bash
git add backend/src/battle-rules/ap-pool.ts backend/src/battle-rules/types.ts backend/test/battle-rules/ap-pool.test.ts
git commit -m "$(cat <<'EOF'
Adiciona ApPool no mirror TypeScript (Bloco 2a)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: `battle-state.ts` ganha `ap`

**Files:**
- Modify: `backend/src/battle-rules/types.ts`, `backend/src/battle-rules/battle-state.ts`
- Test: `backend/test/battle-rules/battle-state.test.ts`

**Interfaces:**
- Consumes: `ApPool` (Task 4).
- Produces: `BattleState.ap: Readonly<Record<string, ApPool>>`; `createBattleState`'s `input.ap` opcional; `apOf(state, combatantId)`, `withApRegenerated(state, combatantId)`, `withApSpent(state, combatantId, amount)`.

- [ ] **Step 1: Escrever os testes falhos**

Em `backend/test/battle-rules/battle-state.test.ts`, adicionar o import:

```ts
import {
  apOf,
  createBattleState,
  hasStatus,
  hpOf,
  opponentOf,
  statusesOf,
  withApRegenerated,
  withApSpent,
  withDamage,
  withMaxHpIncreased,
  withStatusApplied,
  withStatusRemoved,
  withStatusesTicked,
} from "../../src/battle-rules/battle-state.js";
```

E os testes novos ao final do arquivo:

```ts
test("defaults both combatants to 5 max, 0 current AP", () => {
  const state = createBattleState({
    playerAId: "a",
    playerBId: "b",
    currentTurnId: "a",
  });
  assert.deepEqual(apOf(state, "a"), { max: 5, current: 0 });
  assert.deepEqual(apOf(state, "b"), { max: 5, current: 0 });
});

test("createBattleState accepts a seeded AP override", () => {
  const state = createBattleState({
    playerAId: "a",
    playerBId: "b",
    currentTurnId: "a",
    ap: { a: { max: 5, current: 3 } },
  });
  assert.deepEqual(apOf(state, "a"), { max: 5, current: 3 });
  assert.deepEqual(apOf(state, "b"), { max: 5, current: 0 });
});

test("withApRegenerated increments only the target's AP", () => {
  const state = createBattleState({ playerAId: "a", playerBId: "b", currentTurnId: "a" });
  const updated = withApRegenerated(state, "a");
  assert.deepEqual(apOf(updated, "a"), { max: 5, current: 1 });
  assert.deepEqual(apOf(updated, "b"), { max: 5, current: 0 });
});

test("withApSpent decrements only the target's AP", () => {
  const state = createBattleState({
    playerAId: "a",
    playerBId: "b",
    currentTurnId: "a",
    ap: { a: { max: 5, current: 3 } },
  });
  const updated = withApSpent(state, "a", 3);
  assert.deepEqual(apOf(updated, "a"), { max: 5, current: 0 });
});
```

- [ ] **Step 2: Rodar os testes e confirmar que falham**

Run: `cd backend && npx tsx --test test/battle-rules/battle-state.test.ts`
Expected: os testes antigos PASS, os novos FAIL — `ap`/`apOf`/`withApRegenerated`/`withApSpent` não existem ainda.

- [ ] **Step 3: Implementar `ap` em `BattleState`/`createBattleState`**

Em `backend/src/battle-rules/types.ts`, adicionar `ap` na interface `BattleState`:

```ts
export interface BattleState {
  readonly playerAId: string;
  readonly playerBId: string;
  readonly currentTurnId: string;
  readonly activeFieldEffects: readonly FieldEffect[];
  readonly hp: Readonly<Record<string, HpPool>>;
  readonly ap: Readonly<Record<string, ApPool>>;
  readonly combatantStatuses: Readonly<Record<string, readonly ActiveStatus[]>>;
  readonly winner: string | null;
}
```

Em `backend/src/battle-rules/battle-state.ts`, adicionar o import:

```ts
import { tick as tickStatus, isExpired } from "./active-status.js";
import {
  canAfford as apCanAfford,
  withRegenerated as apWithRegenerated,
  withSpent as apWithSpent,
} from "./ap-pool.js";
import {
  withDamage as poolWithDamage,
  withMaxIncreased as poolWithMaxIncreased,
  isDefeated,
} from "./hp-pool.js";
import { TurnValidationError } from "./errors.js";
import type { ActiveStatus, ApPool, BattleState, FieldEffect, HpPool } from "./types.js";
```

Ajustar `createBattleState`'s assinatura e corpo — adicionar `ap` opcional e semeá-lo (logo depois do bloco `hp`):

```dart
export function createBattleState(input: {
  playerAId: string;
  playerBId: string;
  currentTurnId: string;
  activeFieldEffects?: readonly FieldEffect[];
  hp?: Readonly<Record<string, HpPool>>;
  ap?: Readonly<Record<string, ApPool>>;
  combatantStatuses?: Readonly<Record<string, readonly ActiveStatus[]>>;
  winner?: string | null;
}): BattleState {
  if (input.playerAId === input.playerBId) {
    throw new TurnValidationError(
      "playerAId and playerBId must be distinct",
    );
  }
  if (
    input.currentTurnId !== input.playerAId &&
    input.currentTurnId !== input.playerBId
  ) {
    throw new TurnValidationError(
      "currentTurnId must be playerAId or playerBId",
    );
  }

  return {
    playerAId: input.playerAId,
    playerBId: input.playerBId,
    currentTurnId: input.currentTurnId,
    activeFieldEffects: input.activeFieldEffects ?? [],
    hp: {
      [input.playerAId]: input.hp?.[input.playerAId] ?? { max: 100, current: 100 },
      [input.playerBId]: input.hp?.[input.playerBId] ?? { max: 100, current: 100 },
    },
    ap: {
      [input.playerAId]: input.ap?.[input.playerAId] ?? { max: 5, current: 0 },
      [input.playerBId]: input.ap?.[input.playerBId] ?? { max: 5, current: 0 },
    },
    combatantStatuses: {
      [input.playerAId]: input.combatantStatuses?.[input.playerAId] ?? [],
      [input.playerBId]: input.combatantStatuses?.[input.playerBId] ?? [],
    },
    winner: input.winner ?? null,
  };
}
```

(Note: essa assinatura em Dart-fence acima é só formatação — o arquivo é TypeScript; escreva-o como `.ts` de verdade, sem a cerca `dart`.)

E os três métodos novos, logo depois de `withMaxHpIncreased`:

```ts
/** AP pool of a combatant. */
export function apOf(state: BattleState, combatantId: string): ApPool {
  const pool = state.ap[combatantId];
  if (!pool) {
    throw new TurnValidationError(
      `"${combatantId}" is not part of this battle`,
    );
  }
  return pool;
}

/** Returns a new state with `combatantId`'s AP incremented by 1 (clamped
 * at their max) — happens at the start of their own turn, before
 * turn-engine.ts checks whether they can afford a combination. */
export function withApRegenerated(state: BattleState, combatantId: string): BattleState {
  return {
    ...state,
    ap: { ...state.ap, [combatantId]: apWithRegenerated(apOf(state, combatantId)) },
  };
}

/** Returns a new state with `amount` of AP subtracted from
 * `combatantId`'s pool. */
export function withApSpent(state: BattleState, combatantId: string, amount: number): BattleState {
  return {
    ...state,
    ap: { ...state.ap, [combatantId]: apWithSpent(apOf(state, combatantId), amount) },
  };
}
```

(`apCanAfford` fica importado aqui pra ser reaproveitado por `turn-engine.ts` na Task 6, não é usado diretamente dentro de `battle-state.ts` — remova o import se o linter reclamar de import não usado, e importe direto em `turn-engine.ts` em vez disso.)

- [ ] **Step 4: Rodar os testes e confirmar que passam**

Run: `cd backend && npx tsx --test test/battle-rules/battle-state.test.ts`
Expected: PASS (todos os testes do arquivo, incluindo os novos).

- [ ] **Step 5: Rodar o typecheck**

Run: `cd backend && npx tsc --noEmit`
Expected: sem erros. Se `apCanAfford` estiver importado sem uso em `battle-state.ts`, remova esse import específico (fica só em `turn-engine.ts`, Task 6).

- [ ] **Step 6: Commit**

```bash
git add backend/src/battle-rules/types.ts backend/src/battle-rules/battle-state.ts backend/test/battle-rules/battle-state.test.ts
git commit -m "$(cat <<'EOF'
BattleState (TypeScript) ganha AP por jogador (Bloco 2a)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: `turn-engine.ts` gasta AP e aplica dano básico

**Files:**
- Modify: `backend/src/battle-rules/turn-engine.ts`
- Test: `backend/test/battle-rules/turn-engine.test.ts` (reescrita completa — mesmo motivo da Task 3)

**Interfaces:**
- Consumes: `apOf`/`withApRegenerated`/`withApSpent` (Task 5); `canAfford` (Task 4).

- [ ] **Step 1: Substituir `turn-engine.test.ts` por inteiro**

Substituir todo o conteúdo de `backend/test/battle-rules/turn-engine.test.ts` por:

```ts
import { test } from "node:test";
import assert from "node:assert/strict";

import {
  apOf,
  createBattleState,
  hasStatus,
  hpOf,
  withStatusApplied,
} from "../../src/battle-rules/battle-state.js";
import { defaultCombinationBook } from "../../src/battle-rules/combination-book.js";
import { propagation, volatility } from "../../src/battle-rules/combination-modifiers.js";
import { TurnValidationError } from "../../src/battle-rules/errors.js";
import { playTurn } from "../../src/battle-rules/turn-engine.js";

function startState() {
  return createBattleState({
    playerAId: "a",
    playerBId: "b",
    currentTurnId: "a",
    // Convenient default for tests that just need one combo to be
    // affordable right away — tests exercising the AP mechanic itself,
    // or needing more than one combo in a row, override this.
    ap: { a: { max: 5, current: 3 }, b: { max: 5, current: 3 } },
  });
}

test("throws if no elements are played", () => {
  assert.throws(
    () => playTurn(startState(), { actorId: "a", elementIds: [] }, defaultCombinationBook),
    TurnValidationError,
  );
});

test("rejects an action from a combatant whose turn it is not", () => {
  assert.throws(
    () =>
      playTurn(
        startState(),
        { actorId: "b", elementIds: ["fire"] },
        defaultCombinationBook,
      ),
    TurnValidationError,
  );
});

test("passes the turn to the opponent after a valid action", () => {
  const result = playTurn(
    startState(),
    { actorId: "a", elementIds: ["fire"] },
    defaultCombinationBook,
  );
  assert.equal(result.state.currentTurnId, "b");
});

test("a single played element never triggers a combination", () => {
  const result = playTurn(
    startState(),
    { actorId: "a", elementIds: ["fire"] },
    defaultCombinationBook,
  );
  assert.equal(result.triggeredCombinationId, null);
  assert.deepEqual(result.state.activeFieldEffects, []);
});

test("playing a known 2-element combination adds it to the field", () => {
  const result = playTurn(
    startState(),
    { actorId: "a", elementIds: ["fire", "wind"] },
    defaultCombinationBook,
  );
  assert.equal(result.triggeredCombinationId, "ignited_storm");
  assert.equal(result.state.activeFieldEffects.length, 1);
  assert.equal(result.state.activeFieldEffects[0]?.id, "ignited_storm");
});

test("playing an unknown combination advances the turn without adding a field effect", () => {
  const result = playTurn(
    startState(),
    { actorId: "a", elementIds: ["ice", "shadow"] },
    defaultCombinationBook,
  );
  assert.equal(result.triggeredCombinationId, null);
  assert.deepEqual(result.state.activeFieldEffects, []);
  assert.equal(result.state.currentTurnId, "b");
});

test("field effects accumulate across turns", () => {
  const first = playTurn(
    startState(),
    { actorId: "a", elementIds: ["fire", "wind"] },
    defaultCombinationBook,
  );
  const second = playTurn(
    first.state,
    { actorId: "b", elementIds: ["water", "lightning"] },
    defaultCombinationBook,
  );
  assert.equal(second.state.activeFieldEffects.length, 2);
});

test("a triggered combination damages the opponent, not the actor", () => {
  const result = playTurn(
    startState(),
    { actorId: "a", elementIds: ["fire", "wind"] },
    defaultCombinationBook,
  );
  assert.deepEqual(hpOf(result.state, "b"), { max: 100, current: 80 });
  assert.deepEqual(hpOf(result.state, "a"), { max: 100, current: 100 });
});

test("an unknown combination deals no damage", () => {
  const result = playTurn(
    startState(),
    { actorId: "a", elementIds: ["ice", "shadow"] },
    defaultCombinationBook,
  );
  assert.deepEqual(hpOf(result.state, "b"), { max: 100, current: 100 });
});

test("sets a winner once repeated basic (single-element) damage defeats a combatant", () => {
  // 5 basic damage per hit, always affordable (0 AP) — 20 hits defeat
  // 100 HP. Isolates "playTurn sets a winner"; combo/AP math is covered
  // by the AP-specific tests below.
  let state = startState();
  for (let i = 0; i < 19; i++) {
    state = playTurn(state, { actorId: "a", elementIds: ["fire"] }, defaultCombinationBook).state;
    state = playTurn(state, { actorId: "b", elementIds: ["ice"] }, defaultCombinationBook).state;
  }
  assert.equal(state.winner, null);
  const final = playTurn(
    state,
    { actorId: "a", elementIds: ["fire"] },
    defaultCombinationBook,
  );
  assert.equal(final.state.winner, "a");
});

test("throws when playing a turn after the battle is already over", () => {
  let state = startState();
  for (let i = 0; i < 19; i++) {
    state = playTurn(state, { actorId: "a", elementIds: ["fire"] }, defaultCombinationBook).state;
    state = playTurn(state, { actorId: "b", elementIds: ["ice"] }, defaultCombinationBook).state;
  }
  state = playTurn(state, { actorId: "a", elementIds: ["fire"] }, defaultCombinationBook).state;
  assert.equal(state.winner, "a");

  assert.throws(
    () => playTurn(state, { actorId: "b", elementIds: ["ice"] }, defaultCombinationBook),
    TurnValidationError,
  );
});

test("Shield blocks the next combo damage and is consumed", () => {
  const state = withStatusApplied(startState(), "b", {
    effectId: "shield",
    turnsRemaining: null,
    damagePerTick: 0,
  });

  const result = playTurn(
    state,
    { actorId: "a", elementIds: ["fire", "wind"] },
    defaultCombinationBook,
  );

  assert.equal(hpOf(result.state, "b").current, 100);
  assert.equal(hasStatus(result.state, "b", "shield"), false);
});

test("Shield does not block a second hit after being consumed", () => {
  let state = withStatusApplied(
    createBattleState({
      playerAId: "a",
      playerBId: "b",
      currentTurnId: "a",
      ap: { a: { max: 5, current: 4 } },
    }),
    "b",
    { effectId: "shield", turnsRemaining: null, damagePerTick: 0 },
  );

  state = playTurn(
    state,
    { actorId: "a", elementIds: ["fire", "wind"] },
    defaultCombinationBook,
  ).state; // blocked, shield consumed (4 seeded + 1 regen - 3 spent = 2 left)
  state = playTurn(
    state,
    { actorId: "b", elementIds: ["ice"] },
    defaultCombinationBook,
  ).state; // no-op, just passes the turn back
  state = playTurn(
    state,
    { actorId: "a", elementIds: ["fire", "wind"] },
    defaultCombinationBook,
  ).state; // 2 + 1 regen = 3, affordable again — not blocked this time

  assert.equal(hpOf(state, "b").current, 80);
});

test(
  "a status with damagePerTick damages its owner at the end of every " +
    "playTurn call, including the tick that expires it — on top of the " +
    "actor's own basic damage",
  () => {
    let state = withStatusApplied(startState(), "b", {
      effectId: "burn",
      turnsRemaining: 2,
      damagePerTick: 8,
    });

    state = playTurn(
      state,
      { actorId: "a", elementIds: ["fire"] },
      defaultCombinationBook,
    ).state;
    // b: 100 - 5 (a's basic damage) - 8 (first DOT tick) = 87
    assert.equal(hpOf(state, "b").current, 87);

    state = playTurn(
      state,
      { actorId: "b", elementIds: ["water"] },
      defaultCombinationBook,
    ).state;
    // a: 100 - 5 (b's basic damage) = 95
    // b: 87 - 8 (second DOT tick, expires) = 79
    assert.equal(hpOf(state, "a").current, 95);
    assert.equal(hpOf(state, "b").current, 79);
    assert.equal(hasStatus(state, "b", "burn"), false);
  },
);

test("DOT damage alone can set a winner", () => {
  // b's maxHp is 10, not 5: a's basic damage (5) alone must not be
  // enough to defeat them — only the DOT tick (8) on top of it should.
  const state = withStatusApplied(
    createBattleState({
      playerAId: "a",
      playerBId: "b",
      currentTurnId: "a",
      hp: { a: { max: 100, current: 100 }, b: { max: 10, current: 10 } },
    }),
    "b",
    { effectId: "burn", turnsRemaining: 1, damagePerTick: 8 },
  );

  const result = playTurn(
    state,
    { actorId: "a", elementIds: ["ice"] },
    defaultCombinationBook,
  );

  assert.equal(result.state.winner, "a");
});

test(
  "when DOT ticks would defeat both combatants in the same resolution, " +
    "the actor wins the tie",
  () => {
    // Both start at 8 HP (not 5): a's basic damage to b alone must not
    // decide the winner ahead of the DOT tick this test is about.
    let state = createBattleState({
      playerAId: "a",
      playerBId: "b",
      currentTurnId: "a",
      hp: { a: { max: 8, current: 8 }, b: { max: 8, current: 8 } },
    });
    state = withStatusApplied(state, "a", {
      effectId: "burn",
      turnsRemaining: 1,
      damagePerTick: 8,
    });
    state = withStatusApplied(state, "b", {
      effectId: "burn",
      turnsRemaining: 1,
      damagePerTick: 8,
    });

    const result = playTurn(
      state,
      { actorId: "a", elementIds: ["ice"] },
      defaultCombinationBook,
    );

    assert.equal(hpOf(result.state, "a").current, 0);
    assert.equal(hpOf(result.state, "b").current, 0);
    assert.equal(result.state.winner, "a");
  },
);

test(
  "applies combinationModifiers to a triggered combination's field effect " +
    "before adding it to the field",
  () => {
    const result = playTurn(
      startState(),
      { actorId: "a", elementIds: ["fire", "wind"] },
      defaultCombinationBook,
      [propagation],
    );

    assert.equal(result.state.activeFieldEffects[0]?.area, 3);
  },
);

test("combinationModifiers apply in order", () => {
  const result = playTurn(
    startState(),
    { actorId: "a", elementIds: ["fire", "wind"] },
    defaultCombinationBook,
    [propagation, propagation],
  );

  assert.equal(result.state.activeFieldEffects[0]?.area, 5);
});

test("combinationModifiers are ignored when no combination triggers", () => {
  const result = playTurn(
    startState(),
    { actorId: "a", elementIds: ["fire"] },
    defaultCombinationBook,
    [propagation],
  );

  assert.deepEqual(result.state.activeFieldEffects, []);
});

test("volatility reduces a triggered combination's duration", () => {
  const result = playTurn(
    startState(),
    { actorId: "a", elementIds: ["fire", "wind"] },
    defaultCombinationBook,
    [volatility],
  );

  // ignited_storm has a null (permanent) duration — volatility leaves it
  // unchanged, same as in battle_engine.
  assert.equal(result.state.activeFieldEffects[0]?.duration, null);
});

test("regenerates 1 AP for the actor at the start of their turn", () => {
  const state = createBattleState({ playerAId: "a", playerBId: "b", currentTurnId: "a" });
  const result = playTurn(state, { actorId: "a", elementIds: ["fire"] }, defaultCombinationBook);

  assert.deepEqual(apOf(result.state, "a"), { max: 5, current: 1 });
  assert.deepEqual(apOf(result.state, "b"), { max: 5, current: 0 });
});

test("AP regeneration is clamped at max", () => {
  const state = createBattleState({
    playerAId: "a",
    playerBId: "b",
    currentTurnId: "a",
    ap: { a: { max: 5, current: 5 } },
  });
  const result = playTurn(state, { actorId: "a", elementIds: ["fire"] }, defaultCombinationBook);

  assert.equal(apOf(result.state, "a").current, 5);
});

test("rejects a 2-element combination without enough AP", () => {
  const state = createBattleState({ playerAId: "a", playerBId: "b", currentTurnId: "a" });
  assert.throws(
    () => playTurn(state, { actorId: "a", elementIds: ["fire", "wind"] }, defaultCombinationBook),
    TurnValidationError,
  );
});

test("rejects a 3-element combination that only affords a 2-element one", () => {
  const state = createBattleState({
    playerAId: "a",
    playerBId: "b",
    currentTurnId: "a",
    ap: { a: { max: 5, current: 3 } },
  });
  assert.throws(
    () =>
      playTurn(
        state,
        { actorId: "a", elementIds: ["earth", "fire", "water"] },
        defaultCombinationBook,
      ),
    TurnValidationError,
  );
});

test("spends 3 AP on a successful 2-element combination", () => {
  const result = playTurn(
    startState(),
    { actorId: "a", elementIds: ["fire", "wind"] },
    defaultCombinationBook,
  );
  // startState seeds 3 + 1 regen = 4, minus 3 spent = 1
  assert.equal(apOf(result.state, "a").current, 1);
});

test("spends all 5 AP on a successful 3-element combination", () => {
  const state = createBattleState({
    playerAId: "a",
    playerBId: "b",
    currentTurnId: "a",
    ap: { a: { max: 5, current: 5 } },
  });
  const result = playTurn(
    state,
    { actorId: "a", elementIds: ["earth", "fire", "water"] },
    defaultCombinationBook,
  );
  assert.equal(apOf(result.state, "a").current, 0);
});
```

- [ ] **Step 2: Rodar os testes e confirmar as falhas esperadas**

Run: `cd backend && npx tsx --test test/battle-rules/turn-engine.test.ts`
Expected: FAIL em massa.

- [ ] **Step 3: Implementar a mudança em `turn-engine.ts`**

Substituir todo o conteúdo de `backend/src/battle-rules/turn-engine.ts` por:

```ts
import { canAfford } from "./ap-pool.js";
import {
  hasStatus,
  opponentOf,
  statusesOf,
  withApRegenerated,
  withApSpent,
  withDamage,
  withStatusesTicked,
  withStatusRemoved,
  apOf,
} from "./battle-state.js";
import type { CombinationBook } from "./combination-book.js";
import type { CombinationModifier } from "./combination-modifiers.js";
import { TurnValidationError } from "./errors.js";
import { SHIELD_STATUS_ID } from "./status-effects.js";
import type { BattleState, TurnAction, TurnResult } from "./types.js";

const BASIC_DAMAGE = 5;
const COMBO_AP_COST: Record<number, number> = { 2: 3, 3: 5 };

/**
 * Server-authoritative mirror of TurnEngine.playTurn in battle_engine.
 * Rejects an action if the battle is already over or outside the actor's
 * turn, regenerates 1 AP for the actor (clamped at their max), rejects
 * the whole action (no AP spent, no damage, turn doesn't pass) if 2-3
 * elements were played and the actor can't afford it, resolves a
 * combination from 2-3 played elements, runs it through
 * `combinationModifiers` (the actor's granted CombinationModifiers — see
 * skill-tree.ts), adds the (possibly modified) result to the field,
 * damages the opponent unless Escudo blocks it (consuming it instead), a
 * single played element always deals a flat basic damage instead (same
 * Escudo rule), passes the turn, ticks every active status for both
 * combatants (applying `damagePerTick`, including the tick that expires
 * it), and sets the winner once a combatant reaches 0 HP. Does not itself
 * know about Mutations/AbilityEffect (a mutation's own status/field
 * effect) — that's ability-engine.ts, one layer up, same split as
 * TurnEngine/AbilityEngine in battle_engine (see DECISION-025).
 */
export function playTurn(
  state: BattleState,
  action: TurnAction,
  combinationBook: CombinationBook,
  combinationModifiers: readonly CombinationModifier[] = [],
): TurnResult {
  if (state.winner !== null) {
    throw new TurnValidationError("the battle is already over");
  }
  if (action.elementIds.length === 0) {
    throw new TurnValidationError("must play at least one element");
  }
  if (action.actorId !== state.currentTurnId) {
    throw new TurnValidationError(`it is not "${action.actorId}"'s turn`);
  }

  let nextState = withApRegenerated(state, action.actorId);

  const elementCount = action.elementIds.length;
  if (elementCount >= 2) {
    const cost = COMBO_AP_COST[elementCount]!;
    if (!canAfford(apOf(nextState, action.actorId), cost)) {
      throw new TurnValidationError(
        `not enough AP for a ${elementCount}-element combination`,
      );
    }
    nextState = withApSpent(nextState, action.actorId, cost);
  }

  let combination =
    elementCount >= 2
      ? combinationBook.resolve(action.elementIds)
      : null;
  if (combination) {
    for (const modifier of combinationModifiers) {
      combination = modifier.apply(combination);
    }
  }

  const opponentId = opponentOf(nextState, action.actorId);
  nextState = {
    ...nextState,
    currentTurnId: opponentId,
    activeFieldEffects: combination
      ? [...nextState.activeFieldEffects, combination]
      : nextState.activeFieldEffects,
  };

  if (combination && combination.damage > 0) {
    nextState = applyDamage(nextState, opponentId, combination.damage);
  } else if (elementCount === 1) {
    nextState = applyDamage(nextState, opponentId, BASIC_DAMAGE);
  }

  nextState = tickStatusDamage(nextState, action.actorId);

  return {
    state: nextState,
    triggeredCombinationId: combination?.id ?? null,
  };
}

function applyDamage(
  state: BattleState,
  targetId: string,
  damage: number,
): BattleState {
  if (hasStatus(state, targetId, SHIELD_STATUS_ID)) {
    return withStatusRemoved(state, targetId, SHIELD_STATUS_ID);
  }
  return withDamage(state, targetId, damage);
}

/** Ticks damage-over-time statuses for both combatants. `actorId` is
 * processed last so that, if both combatants would be defeated by this
 * same tick, `withDamage`'s "first defeat sets the winner" rule makes the
 * actor the winner (mirrors TurnEngine's tie-break in battle_engine). */
function tickStatusDamage(state: BattleState, actorId: string): BattleState {
  let result = state;
  const opponentId = opponentOf(state, actorId);
  for (const combatantId of [opponentId, actorId]) {
    for (const status of statusesOf(state, combatantId)) {
      if (status.damagePerTick > 0) {
        result = withDamage(result, combatantId, status.damagePerTick);
      }
    }
  }
  return withStatusesTicked(result);
}
```

- [ ] **Step 4: Rodar os testes e confirmar que passam**

Run: `cd backend && npx tsx --test test/battle-rules/turn-engine.test.ts`
Expected: PASS (todos os testes do arquivo).

- [ ] **Step 5: Rodar o typecheck**

Run: `cd backend && npx tsc --noEmit`
Expected: sem erros.

- [ ] **Step 6: Commit**

```bash
git add backend/src/battle-rules/turn-engine.ts backend/test/battle-rules/turn-engine.test.ts
git commit -m "$(cat <<'EOF'
turn-engine.ts gasta AP em combos e aplica dano básico (Bloco 2a)

Espelha a mudança do TurnEngine (Dart) — ver Task 3.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: `parse.ts`/`validate-turn.ts` + consertar os testes de integração restantes

**Files:**
- Modify: `backend/src/battle-rules/parse.ts`, `backend/src/routes/validate-turn.ts`
- Test: `backend/test/routes/validate-turn.test.ts`, `backend/test/battle-rules/ability-engine.test.ts`, `backend/test/matches/match-store.test.ts`, `backend/test/routes/matches.test.ts`

**Interfaces:**
- Consumes: `ApPool` (Task 4), `createBattleState`'s `ap` (Task 5).

- [ ] **Step 1: Adicionar `parseApPool`/`parseAp`**

Em `backend/src/battle-rules/parse.ts`, adicionar o import de `ApPool`:

```ts
import { isNonEmptyString } from "../http/validation.js";
import { TurnValidationError } from "./errors.js";
import type { ActiveStatus, ApPool, FieldEffect, HpPool, TurnAction } from "./types.js";
```

E as duas funções novas, logo depois de `parseHp`:

```ts
export function parseApPool(value: unknown): ApPool {
  if (typeof value !== "object" || value === null) {
    throw new TurnValidationError("each AP pool must be an object");
  }
  const { max, current } = value as Record<string, unknown>;

  if (typeof max !== "number") {
    throw new TurnValidationError("AP pool max must be a number");
  }
  if (typeof current !== "number") {
    throw new TurnValidationError("AP pool current must be a number");
  }

  return { max, current };
}

/** Parses the optional `state.ap` map sent by a stateless caller (see
 * /battles/validate-turn) — keyed by combatant id, same shape
 * createBattleState accepts. Returns undefined (letting createBattleState
 * apply its own 5/0 default) when absent. */
export function parseAp(
  value: unknown,
): Record<string, ApPool> | undefined {
  if (value === undefined) return undefined;
  if (typeof value !== "object" || value === null) {
    throw new TurnValidationError("state.ap must be an object");
  }
  const entries = Object.entries(value as Record<string, unknown>);
  return Object.fromEntries(
    entries.map(([id, pool]) => [id, parseApPool(pool)]),
  );
}
```

- [ ] **Step 2: Passar `ap` pro `createBattleState` em `validate-turn.ts`**

Em `backend/src/routes/validate-turn.ts`, adicionar o import de `parseAp` e usá-lo:

```ts
import {
  parseAp,
  parseCombatantStatuses,
  parseFieldEffect,
  parseHp,
  parseTurnAction,
} from "../battle-rules/parse.js";
```

```ts
  return {
    state: createBattleState({
      playerAId: stateInput.playerAId,
      playerBId: stateInput.playerBId,
      currentTurnId: stateInput.currentTurnId,
      activeFieldEffects,
      hp: parseHp(stateInput.hp),
      ap: parseAp(stateInput.ap),
      combatantStatuses: parseCombatantStatuses(stateInput.combatantStatuses),
      winner: (stateInput.winner as string | null | undefined) ?? null,
    }),
    action: parseTurnAction(action),
  };
```

- [ ] **Step 3: Consertar `validate-turn.test.ts`**

Em `backend/test/routes/validate-turn.test.ts`, trocar `baseState`:

```ts
function baseState() {
  return {
    playerAId: "a",
    playerBId: "b",
    currentTurnId: "a",
    activeFieldEffects: [] as unknown[],
    ap: { a: { max: 5, current: 3 }, b: { max: 5, current: 3 } },
  };
}
```

E corrigir o número no teste "carries over a damage-over-time status and ticks it" (a agora também causa 5 de dano básico em b, jogando `['ice']`, além do tick de 8 do DOT):

```ts
test("carries over a damage-over-time status and ticks it", async () => {
  await withServer(async (baseUrl) => {
    const response = await fetch(`${baseUrl}/battles/validate-turn`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        state: {
          ...baseState(),
          combatantStatuses: {
            b: [{ effectId: "burn", turnsRemaining: 2, damagePerTick: 8 }],
          },
        },
        action: { actorId: "a", elementIds: ["ice"] },
      }),
    });
    const body = await readBody(response);

    assert.equal(response.status, 200);
    assert.equal(body.state?.hp?.b?.current, 87); // 100 - 5 (basic) - 8 (DOT tick)
    assert.deepEqual(body.state?.combatantStatuses?.b, [
      { effectId: "burn", turnsRemaining: 1, damagePerTick: 8 },
    ]);
  });
});
```

- [ ] **Step 4: Rodar `validate-turn.test.ts` e confirmar que passa**

Run: `cd backend && npx tsx --test test/routes/validate-turn.test.ts`
Expected: PASS (todos os testes do arquivo).

- [ ] **Step 5: Consertar `ability-engine.test.ts`**

Em `backend/test/battle-rules/ability-engine.test.ts`, trocar `startState`:

```ts
function startState() {
  return createBattleState({
    playerAId: "a",
    playerBId: "b",
    currentTurnId: "a",
    ap: { a: { max: 5, current: 3 }, b: { max: 5, current: 3 } },
  });
}
```

- [ ] **Step 6: Rodar `ability-engine.test.ts` e confirmar que passa**

Run: `cd backend && npx tsx --test test/battle-rules/ability-engine.test.ts`
Expected: PASS (todos os testes do arquivo).

- [ ] **Step 7: Consertar `match-store.test.ts`**

Em `backend/test/matches/match-store.test.ts`, trocar os três testes afetados. Primeiro, "applyTurn resolves a combination and advances the turn":

```ts
test("applyTurn resolves a combination and advances the turn", () => {
  const store = new MatchStore();
  const created = store.create("ana");
  store.join(created.id, "beto");

  // ana precisa de 3 AP pra um combo de 2 — ela começa em 0, então
  // carrega primeiro com duas jogadas de elemento sozinho (5 de dano
  // básico cada, irrelevante pro que este teste verifica).
  store.applyTurn(created.id, { actorId: "ana", elementIds: ["fire"] }, defaultCombinationBook);
  store.applyTurn(created.id, { actorId: "beto", elementIds: ["ice"] }, defaultCombinationBook);
  store.applyTurn(created.id, { actorId: "ana", elementIds: ["fire"] }, defaultCombinationBook);
  store.applyTurn(created.id, { actorId: "beto", elementIds: ["ice"] }, defaultCombinationBook);

  const { match, result } = store.applyTurn(
    created.id,
    { actorId: "ana", elementIds: ["fire", "wind"] },
    defaultCombinationBook,
  );

  assert.equal(result.triggeredCombinationId, "ignited_storm");
  assert.equal(match.state?.currentTurnId, "beto");
  assert.equal(match.state?.activeFieldEffects.length, 1);
  assert.equal(match.status, "in_progress");
});
```

"applyTurn marks the match finished once a winner is decided":

```ts
test("applyTurn marks the match finished once a winner is decided", () => {
  const store = new MatchStore();
  const created = store.create("ana");
  store.join(created.id, "beto");

  // 5 de dano básico por jogada, sempre de graça — 20 acertos derrubam
  // 100 HP. Isola "MatchStore marca finished", não a matemática de
  // combo/AP (já coberta por turn-engine.test.ts).
  for (let i = 0; i < 19; i++) {
    store.applyTurn(created.id, { actorId: "ana", elementIds: ["fire"] }, defaultCombinationBook);
    store.applyTurn(created.id, { actorId: "beto", elementIds: ["ice"] }, defaultCombinationBook);
  }
  const { match: finished, result } = store.applyTurn(
    created.id,
    { actorId: "ana", elementIds: ["fire"] },
    defaultCombinationBook,
  );

  assert.equal(result.state.winner, "ana");
  assert.equal(finished.status, "finished");
});
```

"applyTurn throws once the match is finished":

```ts
test("applyTurn throws once the match is finished", () => {
  const store = new MatchStore();
  const created = store.create("ana");
  store.join(created.id, "beto");

  for (let i = 0; i < 19; i++) {
    store.applyTurn(created.id, { actorId: "ana", elementIds: ["fire"] }, defaultCombinationBook);
    store.applyTurn(created.id, { actorId: "beto", elementIds: ["ice"] }, defaultCombinationBook);
  }
  store.applyTurn(created.id, { actorId: "ana", elementIds: ["fire"] }, defaultCombinationBook);

  assert.throws(
    () =>
      store.applyTurn(
        created.id,
        { actorId: "beto", elementIds: ["ice"] },
        defaultCombinationBook,
      ),
    (error: unknown) => error instanceof Error && (error as { status?: number }).status === 409,
  );
});
```

E "applyTurn applies a granted combinationModifier to a triggered combo":

```ts
test("applyTurn applies a granted combinationModifier to a triggered combo", () => {
  const store = new MatchStore();
  const created = store.create("ana");
  store.join(created.id, "beto");
  store.unlockSkill(created.id, "ana", "elemental_insight"); // grants Propagação

  store.applyTurn(created.id, { actorId: "ana", elementIds: ["fire"] }, defaultCombinationBook);
  store.applyTurn(created.id, { actorId: "beto", elementIds: ["ice"] }, defaultCombinationBook);
  store.applyTurn(created.id, { actorId: "ana", elementIds: ["fire"] }, defaultCombinationBook);
  store.applyTurn(created.id, { actorId: "beto", elementIds: ["ice"] }, defaultCombinationBook);

  const { match } = store.applyTurn(
    created.id,
    { actorId: "ana", elementIds: ["fire", "wind"] },
    defaultCombinationBook,
  );

  assert.equal(match.state?.activeFieldEffects[0]?.area, 3);
});
```

- [ ] **Step 8: Rodar `match-store.test.ts` e confirmar que passa**

Run: `cd backend && npx tsx --test test/matches/match-store.test.ts`
Expected: PASS (todos os testes do arquivo).

- [ ] **Step 9: Consertar `matches.test.ts` (rota)**

Em `backend/test/routes/matches.test.ts`, no teste "the full section-11 flow...", inserir 4 chamadas de carga antes das duas de combo:

```ts
      const joinResponse = await postJson(
        `${baseUrl}/matches/${created.id}/join`,
        { playerBId: "beto" },
      );
      const joined = (await joinResponse.json()) as MatchBody;
      assert.equal(joinResponse.status, 200);
      assert.equal(joined.status, "in_progress");
      assert.equal(joined.state?.currentTurnId, "ana");

      // ana e beto precisam de 3 AP cada pra um combo de 2 — carrega
      // primeiro com duas jogadas de elemento sozinho cada.
      await postJson(`${baseUrl}/matches/${created.id}/turns`, { actorId: "ana", elementIds: ["fire"] });
      await postJson(`${baseUrl}/matches/${created.id}/turns`, { actorId: "beto", elementIds: ["ice"] });
      await postJson(`${baseUrl}/matches/${created.id}/turns`, { actorId: "ana", elementIds: ["fire"] });
      await postJson(`${baseUrl}/matches/${created.id}/turns`, { actorId: "beto", elementIds: ["ice"] });

      const turnAResponse = await postJson(
        `${baseUrl}/matches/${created.id}/turns`,
        { actorId: "ana", elementIds: ["fire", "wind"] },
      );
```

(o resto do teste continua igual — `turnBResponse` já joga `water`/`lightning` pra beto, que também já carregou 3 AP nas duas rodadas de `ice` acima).

- [ ] **Step 10: Rodar `matches.test.ts` e confirmar que passa**

Run: `cd backend && npx tsx --test test/routes/matches.test.ts`
Expected: PASS (todos os testes do arquivo).

- [ ] **Step 11: Rodar a suíte inteira do backend**

Run: `cd backend && npx tsc --noEmit && npm test`
Expected: sem erros de tipo, todos os testes PASS.

- [ ] **Step 12: Commit**

```bash
git add backend/src/battle-rules/parse.ts backend/src/routes/validate-turn.ts backend/test/routes/validate-turn.test.ts backend/test/battle-rules/ability-engine.test.ts backend/test/matches/match-store.test.ts backend/test/routes/matches.test.ts
git commit -m "$(cat <<'EOF'
Propaga AP pro endpoint stateless e conserta os testes de integração (Bloco 2a)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 8: Cliente Flutter — dados (game_domain)

**Files:**
- Modify: `app/lib/game_domain/multiplayer_models.dart`, `app/lib/game_domain/multiplayer_match.dart`, `app/lib/game_domain/training_match.dart`
- Test: `app/test/game_domain/multiplayer_match_test.dart`, `app/test/game_domain/training_match_test.dart`

**Interfaces:**
- Produces: `RemoteApPool{max,current}`; `RemoteBattleState.ap: Map<String, RemoteApPool>`; `MultiplayerMatch.myAp`/`myApMax`/`opponentAp`/`opponentApMax`; `TrainingMatch({..., ApPool? initialApA, ApPool? initialApB})`; `TrainingMatch.playerAAp`/`playerAApMax`/`playerBAp`/`playerBApMax`.

- [ ] **Step 1: Escrever o teste falho do Multiplayer**

Em `app/test/game_domain/multiplayer_match_test.dart`, no handler de `join` do `_FakeBackend`, adicionar `ap` ao `match['state']`, logo depois de `'combatantStatuses'`:

```dart
        'combatantStatuses': <String, dynamic>{
          match['playerAId'] as String: <dynamic>[
            {'effectId': 'burn', 'turnsRemaining': 2, 'damagePerTick': 8},
          ],
          match['playerBId'] as String: <dynamic>[
            {'effectId': 'shield', 'turnsRemaining': null, 'damagePerTick': 0},
          ],
        },
        'ap': <String, dynamic>{
          match['playerAId'] as String: {'max': 5, 'current': 3},
          match['playerBId'] as String: {'max': 5, 'current': 1},
        },
        'winner': null,
      };
```

E um teste novo, depois do teste `'myActiveStatuses/opponentActiveStatuses resolve id and remainingTurns from combatantStatuses'`:

```dart
  test('myAp/myApMax/opponentAp/opponentApMax resolve from state.ap',
      () async {
    final backend = _FakeBackend();
    final ana = MultiplayerMatch(
      client: MultiplayerClient(baseUrl: 'http://x', httpClient: backend.asClient()),
      localPlayerId: 'ana',
    );
    await ana.create();
    final beto = MultiplayerMatch(
      client: MultiplayerClient(baseUrl: 'http://x', httpClient: backend.asClient()),
      localPlayerId: 'beto',
    );
    await beto.join(ana.matchId!);
    await ana.refresh();

    expect(ana.myAp, 3);
    expect(ana.myApMax, 5);
    expect(ana.opponentAp, 1);
    expect(beto.myAp, 1);
    expect(beto.opponentAp, 3);
  });
```

- [ ] **Step 2: Rodar o teste e confirmar que falha**

Run: `cd app && flutter test test/game_domain/multiplayer_match_test.dart`
Expected: os testes antigos PASS, o novo FAIL — `myAp`/`myApMax`/`opponentAp` não existem ainda.

- [ ] **Step 3: Implementar `RemoteApPool`/`RemoteBattleState.ap`/`MultiplayerMatch`**

Em `app/lib/game_domain/multiplayer_models.dart`, adicionar a classe `RemoteApPool` logo depois de `RemoteActiveStatus`:

```dart
class RemoteApPool {
  final int max;
  final int current;

  const RemoteApPool({required this.max, required this.current});

  factory RemoteApPool.fromJson(Map<String, dynamic> json) {
    return RemoteApPool(max: json['max'] as int, current: json['current'] as int);
  }
}
```

Em `RemoteBattleState`, adicionar o campo `ap` (depois de `combatantStatuses`) e parseá-lo em `fromJson`:

```dart
class RemoteBattleState {
  final String playerAId;
  final String playerBId;
  final String currentTurnId;
  final List<RemoteFieldEffect> activeFieldEffects;
  final Map<String, RemoteHpPool> hp;
  final Map<String, List<RemoteActiveStatus>> combatantStatuses;
  final Map<String, RemoteApPool> ap;
  final String? winner;

  const RemoteBattleState({
    required this.playerAId,
    required this.playerBId,
    required this.currentTurnId,
    required this.activeFieldEffects,
    required this.hp,
    this.combatantStatuses = const {},
    this.ap = const {},
    this.winner,
  });

  factory RemoteBattleState.fromJson(Map<String, dynamic> json) {
    final combatantStatusesJson = json['combatantStatuses'] as Map<String, dynamic>?;
    final apJson = json['ap'] as Map<String, dynamic>?;
    return RemoteBattleState(
      playerAId: json['playerAId'] as String,
      playerBId: json['playerBId'] as String,
      currentTurnId: json['currentTurnId'] as String,
      activeFieldEffects: (json['activeFieldEffects'] as List)
          .map((e) => RemoteFieldEffect.fromJson(e as Map<String, dynamic>))
          .toList(),
      hp: (json['hp'] as Map<String, dynamic>).map(
        (id, pool) => MapEntry(id, RemoteHpPool.fromJson(pool as Map<String, dynamic>)),
      ),
      combatantStatuses: combatantStatusesJson == null
          ? const {}
          : combatantStatusesJson.map(
              (id, statuses) => MapEntry(
                id,
                (statuses as List)
                    .map((s) => RemoteActiveStatus.fromJson(s as Map<String, dynamic>))
                    .toList(),
              ),
            ),
      ap: apJson == null
          ? const {}
          : apJson.map(
              (id, pool) => MapEntry(id, RemoteApPool.fromJson(pool as Map<String, dynamic>)),
            ),
      winner: json['winner'] as String?,
    );
  }
}
```

Em `app/lib/game_domain/multiplayer_match.dart`, adicionar os quatro getters novos, logo depois de `activeFieldEffectBadges`:

```dart
  RemoteApPool? _apOf(String? playerId) {
    if (playerId == null) return null;
    return _match?.state?.ap[playerId];
  }

  int get myAp => _apOf(localPlayerId)?.current ?? 0;
  int get myApMax => _apOf(localPlayerId)?.max ?? 5;
  int get opponentAp => _apOf(_opponentId)?.current ?? 0;
  int get opponentApMax => _apOf(_opponentId)?.max ?? 5;
```

- [ ] **Step 4: Rodar o teste do Multiplayer e confirmar que passa**

Run: `cd app && flutter test test/game_domain/multiplayer_match_test.dart`
Expected: PASS (todos os testes do arquivo, incluindo o novo).

- [ ] **Step 5: Escrever os testes falhos do Treino**

Em `app/test/game_domain/training_match_test.dart`, adicionar 8 seeds de `initialApA`/`initialApB` aos testes que combam, e reescrever o teste de grind — trocar cada trecho abaixo (before → after):

```dart
  test('playing fire+wind triggers Tempestade Ígnea and passes the turn',
      () {
    final match = TrainingMatch();

    match.playElementIds(['fire', 'wind']);
```
por
```dart
  test('playing fire+wind triggers Tempestade Ígnea and passes the turn',
      () {
    final match = TrainingMatch(initialApA: const ApPool(max: 5, current: 3));

    match.playElementIds(['fire', 'wind']);
```

```dart
  test('discovering the same combination twice does not double-count', () {
    final match = TrainingMatch();

    match.playElementIds(['fire', 'wind']); // Jogador A
    match.playElementIds(['fire', 'wind']); // Jogador B, same combo
```
por
```dart
  test('discovering the same combination twice does not double-count', () {
    final match = TrainingMatch(
      initialApA: const ApPool(max: 5, current: 3),
      initialApB: const ApPool(max: 5, current: 3),
    );

    match.playElementIds(['fire', 'wind']); // Jogador A
    match.playElementIds(['fire', 'wind']); // Jogador B, same combo
```

```dart
  test('an unknown combination does not add a field effect but still '
      'passes the turn', () {
    final match = TrainingMatch();

    match.playElementIds(['ice', 'shadow']);
```
por
```dart
  test('an unknown combination does not add a field effect but still '
      'passes the turn', () {
    final match = TrainingMatch(initialApA: const ApPool(max: 5, current: 3));

    match.playElementIds(['ice', 'shadow']);
```

```dart
    test('a triggered combination reduces the opponent\'s current HP', () {
      final match = TrainingMatch();
      match.playElementIds(['fire', 'wind']); // Jogador A, 20 damage
```
por
```dart
    test('a triggered combination reduces the opponent\'s current HP', () {
      final match = TrainingMatch(initialApA: const ApPool(max: 5, current: 3));
      match.playElementIds(['fire', 'wind']); // Jogador A, 20 damage
```

```dart
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
```
por
```dart
    test('ends the match and names the winner once someone reaches 0 HP',
        () {
      final match = TrainingMatch();
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
```

```dart
    test('a Vitalidade bonus unlocked mid-match does not affect prior '
        'damage taken', () {
      final match = TrainingMatch();
      match.playElementIds(['fire', 'wind']); // Jogador A hits B for 20
```
por
```dart
    test('a Vitalidade bonus unlocked mid-match does not affect prior '
        'damage taken', () {
      final match = TrainingMatch(initialApA: const ApPool(max: 5, current: 3));
      match.playElementIds(['fire', 'wind']); // Jogador A hits B for 20
```

```dart
  test('activeFieldEffectBadges resolves id and remainingTurns from a '
      'triggered combination', () {
    final match = TrainingMatch();
    match.playElementIds(['fire', 'wind']); // Tempestade Ígnea
```
por
```dart
  test('activeFieldEffectBadges resolves id and remainingTurns from a '
      'triggered combination', () {
    final match = TrainingMatch(initialApA: const ApPool(max: 5, current: 3));
    match.playElementIds(['fire', 'wind']); // Tempestade Ígnea
```

```dart
  test('unlockedNodeIdsForPlayerA/B and discoveredCombinationIds reflect '
      'real state', () {
    final match = TrainingMatch();
    match.unlockSkillForCurrentPlayer('ember_mastery'); // Jogador A
    match.playElementIds(['fire', 'wind']); // Jogador A, Tempestade Ígnea
```
por
```dart
  test('unlockedNodeIdsForPlayerA/B and discoveredCombinationIds reflect '
      'real state', () {
    final match = TrainingMatch(initialApA: const ApPool(max: 5, current: 3));
    match.unlockSkillForCurrentPlayer('ember_mastery'); // Jogador A
    match.playElementIds(['fire', 'wind']); // Jogador A, Tempestade Ígnea
```

```dart
    test('resets HP/turn/campo but keeps Skill Tree and Discovery Book', () {
      final match = TrainingMatch();
      match.unlockSkillForCurrentPlayer('vitality_training'); // Jogador A
      match.playElementIds(['fire', 'wind']); // Jogador A, descobre Tempestade Ígnea
```
por
```dart
    test('resets HP/turn/campo but keeps Skill Tree and Discovery Book', () {
      final match = TrainingMatch(initialApA: const ApPool(max: 5, current: 3));
      match.unlockSkillForCurrentPlayer('vitality_training'); // Jogador A
      match.playElementIds(['fire', 'wind']); // Jogador A, descobre Tempestade Ígnea
```

E adicionar um teste novo, ao final do `main()` (antes do `}`), cobrindo os getters:

```dart
  test('playerAAp/playerAApMax/playerBAp/playerBApMax reflect real state',
      () {
    final match = TrainingMatch();
    expect(match.playerAAp, 0);
    expect(match.playerAApMax, 5);

    match.playElementIds(['fire']); // Jogador A regenera 1 AP no próprio turno

    expect(match.playerAAp, 1);
    expect(match.playerBAp, 0);
  });
```

- [ ] **Step 6: Rodar os testes e confirmar as falhas esperadas**

Run: `cd app && flutter test test/game_domain/training_match_test.dart`
Expected: FAIL em massa — `initialApA`/`initialApB` não existem ainda, `playerAAp` etc. não existem.

- [ ] **Step 7: Implementar `initialApA`/`initialApB` e os 4 getters em `TrainingMatch`**

Em `app/lib/game_domain/training_match.dart`, ajustar o construtor:

```dart
  /// [initialProgressA]/[initialProgressB]/[initialDiscoveryBook] seedam
  /// uma partida já com progresso de uma partida anterior (Bloco 10 —
  /// persistência local do Modo Treino) — default vazio, mesmo
  /// comportamento de sempre quando não passados. O HP inicial já soma
  /// o bônus de qualquer `MaxHpBonus` que o progresso inicial conceda
  /// (ex: Treino de Vitalidade), não só quando desbloqueado ao vivo
  /// durante a partida. [initialApA]/[initialApB] existem só pra
  /// conveniência de teste (Bloco 2a) — nenhum código de produção
  /// precisa seedar AP, uma partida real sempre começa em 0.
  TrainingMatch({
    SkillProgress? initialProgressA,
    SkillProgress? initialProgressB,
    DiscoveryBook? initialDiscoveryBook,
    ApPool? initialApA,
    ApPool? initialApB,
  }) {
    _progressA = initialProgressA ?? SkillProgress(defaultSkillTree);
    _progressB = initialProgressB ?? SkillProgress(defaultSkillTree);
    _discoveryBook = initialDiscoveryBook ?? DiscoveryBook();
    _state = BattleState.start(
      playerA: _playerA,
      playerB: _playerB,
      playerAMaxHp: _baseMaxHp + _progressA.grantedMaxHpBonus,
      playerBMaxHp: _baseMaxHp + _progressB.grantedMaxHpBonus,
      ap: {
        if (initialApA != null) _playerA: initialApA,
        if (initialApB != null) _playerB: initialApB,
      },
    );
  }
```

E os 4 getters novos, logo depois de `discoveredCombinationIds`:

```dart
  int get playerAAp => _state.apOf(_playerA).current;
  int get playerAApMax => _state.apOf(_playerA).max;
  int get playerBAp => _state.apOf(_playerB).current;
  int get playerBApMax => _state.apOf(_playerB).max;
```

- [ ] **Step 8: Rodar os testes e confirmar que passam**

Run: `cd app && flutter test test/game_domain/training_match_test.dart`
Expected: PASS (todos os testes do arquivo).

- [ ] **Step 9: Commit**

```bash
git add app/lib/game_domain/multiplayer_models.dart app/lib/game_domain/multiplayer_match.dart app/lib/game_domain/training_match.dart app/test/game_domain/multiplayer_match_test.dart app/test/game_domain/training_match_test.dart
git commit -m "$(cat <<'EOF'
Cliente expõe AP (Bloco 2a) e conserta testes que combavam sem carga

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 9: Cliente Flutter — HUD (game_presentation)

**Files:**
- Modify: `app/lib/game_domain/battle_scene_view.dart`, `app/lib/game_presentation/battle_hud_widget.dart`
- Test: `app/test/game_domain/battle_scene_view_test.dart`, `app/test/game_presentation/battle_hud_widget_test.dart`

**Interfaces:**
- Produces: `BattleSceneView.leftAp`/`leftApMax`/`rightAp`/`rightApMax` (`int`, default `0`/`5`).

- [ ] **Step 1: Escrever o teste falho do `BattleSceneView`**

Em `app/test/game_domain/battle_scene_view_test.dart`, adicionar um teste novo ao final do `main()`:

```dart
  test('leftAp/leftApMax/rightAp/rightApMax default to 0/5 and can be set',
      () {
    const withoutAp = BattleSceneView(
      leftCurrentHp: 100, leftMaxHp: 100,
      rightCurrentHp: 100, rightMaxHp: 100,
      isLeftTurn: true,
    );
    expect(withoutAp.leftAp, 0);
    expect(withoutAp.leftApMax, 5);
    expect(withoutAp.rightAp, 0);
    expect(withoutAp.rightApMax, 5);

    const withAp = BattleSceneView(
      leftCurrentHp: 100, leftMaxHp: 100,
      rightCurrentHp: 100, rightMaxHp: 100,
      isLeftTurn: true,
      leftAp: 3,
      rightAp: 5,
    );
    expect(withAp.leftAp, 3);
    expect(withAp.rightAp, 5);
  });
```

- [ ] **Step 2: Rodar o teste e confirmar que falha**

Run: `cd app && flutter test test/game_domain/battle_scene_view_test.dart`
Expected: FAIL — `leftAp`/`leftApMax`/`rightAp`/`rightApMax` não existem ainda.

- [ ] **Step 3: Implementar os campos em `BattleSceneView`**

Em `app/lib/game_domain/battle_scene_view.dart`, adicionar os 4 campos novos (depois de `fieldEffects`) e seus defaults no construtor:

```dart
class BattleSceneView {
  final int leftCurrentHp;
  final int leftMaxHp;
  final int rightCurrentHp;
  final int rightMaxHp;
  final bool isLeftTurn;
  final AttackEvent? lastAttack;
  final String leftLabel;
  final String rightLabel;
  final List<EffectBadgeView> leftStatuses;
  final List<EffectBadgeView> rightStatuses;
  final List<EffectBadgeView> fieldEffects;
  final int leftAp;
  final int leftApMax;
  final int rightAp;
  final int rightApMax;

  const BattleSceneView({
    required this.leftCurrentHp,
    required this.leftMaxHp,
    required this.rightCurrentHp,
    required this.rightMaxHp,
    required this.isLeftTurn,
    this.lastAttack,
    this.leftLabel = 'Esquerda',
    this.rightLabel = 'Direita',
    this.leftStatuses = const [],
    this.rightStatuses = const [],
    this.fieldEffects = const [],
    this.leftAp = 0,
    this.leftApMax = 5,
    this.rightAp = 0,
    this.rightApMax = 5,
  });
}
```

- [ ] **Step 4: Rodar o teste e confirmar que passa**

Run: `cd app && flutter test test/game_domain/battle_scene_view_test.dart`
Expected: PASS (todos os testes do arquivo).

- [ ] **Step 5: Escrever o teste falho do `BattleHudWidget`**

Em `app/test/game_presentation/battle_hud_widget_test.dart`, adicionar um teste novo ao final do `main()`:

```dart
  testWidgets('shows AP pips filled up to ap, empty for the rest',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: BattleHudWidget(
          view: BattleSceneView(
            leftCurrentHp: 100, leftMaxHp: 100,
            rightCurrentHp: 100, rightMaxHp: 100,
            isLeftTurn: true,
            leftLabel: 'Jogador A',
            rightLabel: 'Jogador B',
            leftAp: 2,
            leftApMax: 5,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final pips = tester.widgetList<Container>(
      find.descendant(
        of: find.byKey(const Key('apPips-left')),
        matching: find.byType(Container),
      ),
    );
    expect(pips.length, 5);
    final filled = pips.where((c) {
      final decoration = c.decoration as BoxDecoration?;
      return decoration?.color == const Color(0xFF7C4DFF);
    });
    expect(filled.length, 2);
  });
```

- [ ] **Step 6: Rodar o teste e confirmar que falha**

Run: `cd app && flutter test test/game_presentation/battle_hud_widget_test.dart`
Expected: FAIL — a chave `apPips-left` não existe ainda.

- [ ] **Step 7: Implementar os pips em `BattleHudWidget`/`_HudPanel`**

Em `app/lib/game_presentation/battle_hud_widget.dart`, adicionar os campos `ap`/`apMax` em `_HudPanel` e renderizar os pips logo abaixo da barra de HP (antes dos badges de status) — trocar:

```dart
class _HudPanel extends StatelessWidget {
  const _HudPanel({
    required this.label,
    required this.currentHp,
    required this.maxHp,
    required this.isActive,
    required this.alignEnd,
    required this.statuses,
  });

  final String label;
  final int currentHp;
  final int maxHp;
  final bool isActive;
  final bool alignEnd;
  final List<EffectBadgeView> statuses;
```

por:

```dart
class _HudPanel extends StatelessWidget {
  const _HudPanel({
    required this.label,
    required this.currentHp,
    required this.maxHp,
    required this.isActive,
    required this.alignEnd,
    required this.statuses,
    required this.ap,
    required this.apMax,
  });

  final String label;
  final int currentHp;
  final int maxHp;
  final bool isActive;
  final bool alignEnd;
  final List<EffectBadgeView> statuses;
  final int ap;
  final int apMax;
```

Trocar o trecho que monta o `Text` de HP + o `if (statuses.isNotEmpty)` seguinte por (adicionando a fileira de pips entre os dois):

```dart
          const SizedBox(height: 2),
          Text(
            '$currentHp/$maxHp HP',
            style: const TextStyle(fontSize: 10, color: Color(0xFF555555)),
          ),
          const SizedBox(height: 4),
          Wrap(
            key: Key(alignEnd ? 'apPips-right' : 'apPips-left'),
            spacing: 3,
            alignment: alignEnd ? WrapAlignment.end : WrapAlignment.start,
            children: [
              for (var i = 0; i < apMax; i++)
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < ap ? const Color(0xFF7C4DFF) : const Color(0xFFE0E0E0),
                    border: Border.all(color: const Color(0xFF20242B), width: 1),
                  ),
                ),
            ],
          ),
          if (statuses.isNotEmpty) ...[
```

E na chamada de `_HudPanel` dentro de `BattleHudWidget.build`, passar `ap`/`apMax` nos dois painéis:

```dart
              Expanded(
                child: _HudPanel(
                  label: view.leftLabel,
                  currentHp: view.leftCurrentHp,
                  maxHp: view.leftMaxHp,
                  isActive: view.isLeftTurn,
                  alignEnd: false,
                  statuses: view.leftStatuses,
                  ap: view.leftAp,
                  apMax: view.leftApMax,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _HudPanel(
                  label: view.rightLabel,
                  currentHp: view.rightCurrentHp,
                  maxHp: view.rightMaxHp,
                  isActive: !view.isLeftTurn,
                  alignEnd: true,
                  statuses: view.rightStatuses,
                  ap: view.rightAp,
                  apMax: view.rightApMax,
                ),
              ),
```

- [ ] **Step 8: Rodar o teste e confirmar que passa**

Run: `cd app && flutter test test/game_presentation/battle_hud_widget_test.dart`
Expected: PASS (todos os testes do arquivo).

- [ ] **Step 9: Commit**

```bash
git add app/lib/game_domain/battle_scene_view.dart app/lib/game_presentation/battle_hud_widget.dart app/test/game_domain/battle_scene_view_test.dart app/test/game_presentation/battle_hud_widget_test.dart
git commit -m "$(cat <<'EOF'
Mostra AP como pontinhos no HUD de batalha (Bloco 2a)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 10: Fiação nas telas + tratar o erro de AP insuficiente

**Files:**
- Modify: `app/lib/ui/training_screen.dart`, `app/lib/ui/multiplayer_battle_screen.dart`
- Test: `app/test/training_screen_test.dart`

**Interfaces:**
- Consumes: `TrainingMatch.playerAAp`/`playerAApMax`/`playerBAp`/`playerBApMax` (Task 8); `MultiplayerMatch.myAp`/`myApMax`/`opponentAp`/`opponentApMax` (Task 8); `BattleSceneView.leftAp`/`leftApMax`/`rightAp`/`rightApMax` (Task 9).

- [ ] **Step 1: Escrever o teste falho — capturar `StateError` em `_playTurn`**

Em `app/test/training_screen_test.dart`, adicionar o import:

```dart
import 'package:app/game_domain/training_match.dart';
import 'package:app/game_presentation/pixel_menu_button.dart';
import 'package:app/main.dart';
import 'package:app/ui/training_screen.dart';
import 'package:battle_engine/battle_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
```

Reescrever o primeiro teste do arquivo (que hoje passa por `GameApp()`/navegação da Home) pra ir direto ao `TrainingScreen` com AP já semeado — trocar:

```dart
  testWidgets(
    'selecting fire and wind then playing triggers Tempestade Ígnea and '
    'passes the turn to Jogador B',
    (WidgetTester tester) async {
      await tester.pumpWidget(const GameApp());
      await tester.pump(const Duration(milliseconds: 1)); // resolve o Future.delayed da checagem de atualização

      await tester.tap(find.text('MODO TREINO'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Vez de: Jogador A'), findsOneWidget);
```
por
```dart
  testWidgets(
    'selecting fire and wind then playing triggers Tempestade Ígnea and '
    'passes the turn to Jogador B',
    (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: TrainingScreen(
          initialMatch: TrainingMatch(
            initialApA: const ApPool(max: 5, current: 3),
          ),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Vez de: Jogador A'), findsOneWidget);
```

(o resto do teste, da linha `await tester.tap(find.text('Escolher elementos'));` até o fim, continua igual — só a montagem inicial da tela mudou.)

E um teste novo, ao final do `main()` (antes do `}` de fechamento), cobrindo a rejeição por AP insuficiente:

```dart
  testWidgets(
    'shows a friendly message when a combo is attempted without enough AP',
    (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: TrainingScreen(initialMatch: TrainingMatch()), // AP começa em 0
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
```

- [ ] **Step 2: Rodar os testes e confirmar as falhas esperadas**

Run: `cd app && flutter test test/training_screen_test.dart`
Expected: o primeiro teste ainda passa (comportamento inalterado); o novo teste FAIL — hoje um `StateError` de AP insuficiente não é capturado, derruba a árvore de widgets em vez de mostrar a mensagem.

- [ ] **Step 3: Implementar a captura do erro e a fiação do AP**

Em `app/lib/ui/training_screen.dart`, adicionar `on StateError` em `_playTurn` — trocar:

```dart
        if (_match.isOver) {
          sfxPlayer.play(SfxId.victory);
        }
      } on ArgumentError {
        _error = 'Jogada inválida.';
      }
    });
  }
```
por:
```dart
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
```

E passar o AP pro `BattleSceneView` — trocar:

```dart
                      leftStatuses: _match.playerAActiveStatuses,
                      rightStatuses: _match.playerBActiveStatuses,
                      fieldEffects: _match.activeFieldEffectBadges,
                    ),
                  ),
```
por:
```dart
                      leftStatuses: _match.playerAActiveStatuses,
                      rightStatuses: _match.playerBActiveStatuses,
                      fieldEffects: _match.activeFieldEffectBadges,
                      leftAp: _match.playerAAp,
                      leftApMax: _match.playerAApMax,
                      rightAp: _match.playerBAp,
                      rightApMax: _match.playerBApMax,
                    ),
                  ),
```

Em `app/lib/ui/multiplayer_battle_screen.dart`, passar o AP pro `BattleSceneView` — trocar:

```dart
          leftStatuses: _match.myActiveStatuses,
          rightStatuses: _match.opponentActiveStatuses,
          fieldEffects: _match.activeFieldEffectBadges,
        ),
      ),
```
por:
```dart
          leftStatuses: _match.myActiveStatuses,
          rightStatuses: _match.opponentActiveStatuses,
          fieldEffects: _match.activeFieldEffectBadges,
          leftAp: _match.myAp,
          leftApMax: _match.myApMax,
          rightAp: _match.opponentAp,
          rightApMax: _match.opponentApMax,
        ),
      ),
```

(O Multiplayer não precisa de um novo `on StateError` — a rejeição acontece no backend, vira `MultiplayerException`, e já é capturada pelo `catch` genérico existente de `_playTurn` via `_match.lastError`, mesmo caminho que "não é sua vez" já usa.)

- [ ] **Step 4: Rodar os testes e confirmar que passam**

Run: `cd app && flutter test test/training_screen_test.dart`
Expected: PASS (todos os testes do arquivo, incluindo o novo).

- [ ] **Step 5: Rodar `flutter analyze`**

Run: `cd app && flutter analyze`
Expected: `No issues found!`

- [ ] **Step 6: Rodar a suíte completa do app**

Run: `cd app && flutter test`
Expected: PASS. Se algum outro teste de `multiplayer_battle_screen_test.dart` ou similar falhar por causa dos campos novos de `BattleSceneView` (não deveria, já que têm default), investigue e corrija antes de prosseguir.

- [ ] **Step 7: Commit**

```bash
git add app/lib/ui/training_screen.dart app/lib/ui/multiplayer_battle_screen.dart app/test/training_screen_test.dart
git commit -m "$(cat <<'EOF'
Mostra AP na cena de batalha e trata rejeição por AP insuficiente (Bloco 2a)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 11: Suíte completa, verificação manual e documentação

**Files:**
- Modify: `DECISIONS.md`, `TASKS.md`

**Interfaces:**
- Nenhuma — task de fechamento, sem código novo.

- [ ] **Step 1: Rodar a suíte completa do `battle_engine`**

Run: `cd packages/battle_engine && dart analyze && dart test`
Expected: `No issues found!`, todos os testes PASS.

- [ ] **Step 2: Rodar a suíte completa do backend**

Run: `cd backend && npx tsc --noEmit && npm test`
Expected: sem erros de tipo, todos os testes PASS.

- [ ] **Step 3: Rodar a suíte completa do app**

Run: `cd app && flutter test && flutter analyze`
Expected: todos os testes PASS, `No issues found!`.

- [ ] **Step 4: Verificar manualmente via `flutter run -d web-server`**

Reiniciar o preview com `preview_stop` + `preview_start` completo. No Modo Treino:
- Jogar elemento sozinho (qualquer um) — confirmar que causa dano (a barra de HP do oponente se move) e que o pip de AP acende embaixo da barra de HP de quem jogou.
- Tentar montar um combo de 2 (Fogo+Vento) antes de ter 3 AP — confirmar que aparece "AP insuficiente para essa combinação." e o turno não passa.
- Jogar mais uma ou duas vezes elemento sozinho até ter AP suficiente, então tentar o combo de novo — confirmar que funciona (Tempestade Ígnea dispara, pips de AP descem pra refletir o gasto).
- Nenhum erro no console do navegador.

- [ ] **Step 5: Registrar DECISION-046 em `DECISIONS.md`**

Ler `DECISIONS.md`, localizar a última entrada (`DECISION-045`), e adicionar uma nova entrada `DECISION-046` logo depois, cobrindo:
- Bloco 2a (fora da ordem de prioridade do CLAUDE.md, a pedido direto do usuário depois de jogar): elemento sozinho grátis + 5 de dano direto; combinar 2-3 elementos custa AP (3/5), que acumula entre turnos (não recarrega tudo de uma vez) — mecanismo de fricção pra combos, primeiro de 4 blocos decididos com o usuário (2a AP, 2b elementos bloqueados, 2c ataques equipáveis, 2d UI estilo Pokémon).
- Sincronizado em `battle_engine` (Dart) e `backend/src/battle-rules/` (TypeScript) no mesmo bloco — regra do CLAUDE.md.
- Descoberta durante o plano: a mudança quebrou a maior parte dos testes existentes de `TurnEngine`/`turn-engine.ts` e vários testes de integração do backend/cliente que combavam como primeira ação ou repetidamente sem intervalo — todos corrigidos (semeando AP ou trocando por ataques de elemento sozinho, que já bastam pra maioria das verificações que não são sobre combo em si).
- `TrainingScreen._playTurn` ganhou tratamento pro novo `StateError` de AP insuficiente (mensagem em português, não expõe a mensagem crua do `battle_engine`).

- [ ] **Step 6: Atualizar `TASKS.md`**

Ler `TASKS.md` e mover a entrada do Bloco 2a (custo de AP pra combos) pra DONE, referenciando DECISION-046. Registrar no BACKLOG os Blocos 2b/2c/2d (já combinados com o usuário, ainda não iniciados).

- [ ] **Step 7: Commit**

```bash
git add DECISIONS.md TASKS.md
git commit -m "$(cat <<'EOF'
Registra DECISION-046 e atualiza TASKS.md (custo de AP pra combos)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

## Self-Review

**Cobertura do spec:**
- `ApPool` (Dart + TS) → Tasks 1, 4.
- `BattleState`/`battle-state.ts` ganham `ap` → Tasks 2, 5.
- `TurnEngine.playTurn`/`turn-engine.ts`: regenera, checa custo, rejeita, gasta, dano básico → Tasks 3, 6.
- Sincronização obrigatória com o backend → Tasks 4-7 (mirror completo, incluindo o endpoint stateless).
- Cliente (Treino e Multiplayer): dados → Task 8; HUD (pips) → Task 9; fiação + erro de AP → Task 10.
- "Nenhum teste existente deveria continuar quebrado" → cada task roda a suíte do arquivo tocado; Task 11 roda tudo de ponta a ponta.
- Correção de `TrainingScreen._playTurn` (achado do spec) → Task 10.
- Verificação manual → Task 11.
- Fora de escopo (2b/2c/2d) → não implementado em nenhuma task, registrado no BACKLOG na Task 11.

**Placeholder scan:** nenhum "TBD"/"depois"/passo sem código real — todo Step de código tem o trecho exato (before/after ou arquivo inteiro quando a densidade de mudanças torna isso mais claro que dezenas de diffs).

**Consistência de tipos:** `ApPool{max,current}`/`canAfford`/`withRegenerated`/`withSpent` idênticos entre Dart (Task 1) e TypeScript (Task 4); `BattleState.ap`/`apOf`/`withApRegenerated`/`withApSpent` com as mesmas assinaturas entre onde nascem (Tasks 2, 5) e onde são consumidos (Tasks 3, 6); `RemoteApPool`/`myAp`/`opponentAp`/`playerAAp`/`playerBAp`/`leftAp`/`rightAp` com nomes consistentes entre Tasks 8-10.
