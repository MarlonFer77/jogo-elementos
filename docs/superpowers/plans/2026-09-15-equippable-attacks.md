# Ataques combinados equipáveis (Bloco 2c) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Uma combinação disparada pela primeira vez vira um "ataque" pessoal de quem a disparou; só volta a funcionar de novo se estiver entre os até 3 equipados — trocáveis numa tela nova ("Ataques Combinados"), que abre sozinha quando as 3 vagas já estão cheias.

**Architecture:** Nova classe `AttackLoadout` em `packages/battle_engine`, separada do `DiscoveryBook` já existente (que não muda) — uma por jogador. O gate de "precisa estar equipado" vive inteiramente em `TrainingMatch` (Game Domain), a única camada que conhece progresso persistido por jogador.

**Tech Stack:** Dart (`packages/battle_engine`), Flutter (`app/`) — mesmo stack de todo bloco anterior desta sessão. Sem mudança em TypeScript/backend.

**Spec:** `docs/superpowers/specs/2026-09-15-equippable-attacks-design.md`

## Global Constraints

- Escopo é **só Modo Treino** — nunca tocar `BattleState`, `TurnEngine`, nem `backend/src/battle-rules/` neste plano.
- `AttackLoadout` é uma estrutura **nova e separada** do `DiscoveryBook` já existente — não reaproveitar nem modificar `DiscoveryBook`/`DiscoveryEntry`.
- Máximo de 3 ataques equipados por jogador, sempre.
- Descobrir uma combinação com vaga livre (<3 equipados) equipa automaticamente, sem perguntar. Com as 3 cheias, a tela "Ataques Combinados" abre sozinha pedindo a troca.
- A partir do momento que uma combinação está desbloqueada pra um jogador, só dá pra disparar ela de novo se estiver equipada — tentar sem equipar é rejeitado (`StateError`, mesmo padrão de "AP insuficiente"/"elemento bloqueado").
- Elemento sozinho nunca é afetado por este bloco.
- Um ataque equipado continua exigindo os elementos individuais desbloqueados (Bloco 2b) e continua custando AP pela tabela existente (Bloco 2a) — nada muda nessas regras.
- UI nunca nomeia um tipo do `battle_engine` diretamente (DECISION-011/017).

---

### Task 1: `AttackLoadout` (Dart)

**Files:**
- Create: `packages/battle_engine/lib/src/attack_loadout.dart`
- Create: `packages/battle_engine/test/attack_loadout_test.dart`
- Modify: `packages/battle_engine/lib/battle_engine.dart`

**Interfaces:**
- Produces: `class AttackLoadout { Set<String> unlockedCombinationIds; List<String> equippedCombinationIds; bool isUnlocked(String); bool isEquipped(String); AttackLoadout withUnlocked(String); AttackLoadout withEquipped(List<String>); }`.

- [ ] **Step 1: Write the failing tests**

Create `packages/battle_engine/test/attack_loadout_test.dart`:

```dart
import 'package:battle_engine/battle_engine.dart';
import 'package:test/test.dart';

void main() {
  group('AttackLoadout.isUnlocked/isEquipped', () {
    test('nothing is unlocked or equipped by default', () {
      final loadout = AttackLoadout();
      expect(loadout.isUnlocked('ignited_storm'), isFalse);
      expect(loadout.isEquipped('ignited_storm'), isFalse);
    });
  });

  group('AttackLoadout.withUnlocked', () {
    test('marks the combination as unlocked', () {
      final loadout = AttackLoadout().withUnlocked('ignited_storm');
      expect(loadout.isUnlocked('ignited_storm'), isTrue);
    });

    test('auto-equips when there is room (fewer than 3 equipped)', () {
      final loadout = AttackLoadout().withUnlocked('ignited_storm');
      expect(loadout.isEquipped('ignited_storm'), isTrue);
      expect(loadout.equippedCombinationIds, ['ignited_storm']);
    });

    test('does not auto-equip once 3 are already equipped', () {
      var loadout = AttackLoadout()
          .withUnlocked('a')
          .withUnlocked('b')
          .withUnlocked('c');
      expect(loadout.equippedCombinationIds, ['a', 'b', 'c']);

      loadout = loadout.withUnlocked('d');

      expect(loadout.isUnlocked('d'), isTrue);
      expect(loadout.isEquipped('d'), isFalse);
      expect(loadout.equippedCombinationIds, ['a', 'b', 'c']);
    });

    test('is a no-op if already unlocked', () {
      final once = AttackLoadout().withUnlocked('ignited_storm');
      final twice = once.withUnlocked('ignited_storm');
      expect(twice.unlockedCombinationIds, once.unlockedCombinationIds);
      expect(twice.equippedCombinationIds, once.equippedCombinationIds);
    });
  });

  group('AttackLoadout.withEquipped', () {
    test('replaces the equipped list', () {
      final loadout = AttackLoadout()
          .withUnlocked('a')
          .withUnlocked('b')
          .withUnlocked('c')
          .withUnlocked('d'); // d unlocked but not equipped (3 already full)

      final updated = loadout.withEquipped(['a', 'd']);

      expect(updated.equippedCombinationIds, ['a', 'd']);
      expect(updated.isEquipped('b'), isFalse);
      expect(updated.isEquipped('c'), isFalse);
    });

    test('throws if given more than 3 ids', () {
      final loadout = AttackLoadout()
          .withUnlocked('a')
          .withUnlocked('b')
          .withUnlocked('c')
          .withUnlocked('d');
      expect(
        () => loadout.withEquipped(['a', 'b', 'c', 'd']),
        throwsArgumentError,
      );
    });

    test('throws if an id is not unlocked yet', () {
      final loadout = AttackLoadout().withUnlocked('a');
      expect(
        () => loadout.withEquipped(['a', 'ghost']),
        throwsArgumentError,
      );
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd packages/battle_engine && dart test test/attack_loadout_test.dart`
Expected: FAIL — `AttackLoadout` is not defined yet.

- [ ] **Step 3: Write the implementation**

Create `packages/battle_engine/lib/src/attack_loadout.dart`:

```dart
/// Tracks which [ElementCombination]s a single player has unlocked as a
/// personal "attack" (triggered at least once), and which ≤3 of those
/// are currently equipped — the only ones that player can trigger again
/// (Bloco 2c, DECISION-048). Immutable — [withUnlocked]/[withEquipped]
/// return a new instance. Independent from [DiscoveryBook] (shared,
/// meta-progression-only, unaffected by this class) — see
/// docs/superpowers/specs/2026-09-15-equippable-attacks-design.md for
/// why they're kept separate.
class AttackLoadout {
  final Set<String> unlockedCombinationIds;
  final List<String> equippedCombinationIds;

  AttackLoadout({
    Set<String> unlockedCombinationIds = const {},
    List<String> equippedCombinationIds = const [],
  })  : unlockedCombinationIds = Set.unmodifiable(unlockedCombinationIds),
        equippedCombinationIds = List.unmodifiable(equippedCombinationIds);

  bool isUnlocked(String combinationId) =>
      unlockedCombinationIds.contains(combinationId);

  bool isEquipped(String combinationId) =>
      equippedCombinationIds.contains(combinationId);

  /// Returns a new loadout with [combinationId] marked as unlocked. If
  /// already unlocked, returns this same instance (no-op). If there's
  /// room (fewer than 3 equipped), also equips it automatically.
  AttackLoadout withUnlocked(String combinationId) {
    if (isUnlocked(combinationId)) return this;
    final nextEquipped = equippedCombinationIds.length < 3
        ? [...equippedCombinationIds, combinationId]
        : equippedCombinationIds;
    return AttackLoadout(
      unlockedCombinationIds: {...unlockedCombinationIds, combinationId},
      equippedCombinationIds: nextEquipped,
    );
  }

  /// Returns a new loadout with the equipped set replaced by
  /// [combinationIds]. Throws `ArgumentError` if it has more than 3
  /// ids, or if any id isn't already unlocked.
  AttackLoadout withEquipped(List<String> combinationIds) {
    if (combinationIds.length > 3) {
      throw ArgumentError.value(
        combinationIds,
        'combinationIds',
        'cannot equip more than 3 attacks',
      );
    }
    for (final id in combinationIds) {
      if (!isUnlocked(id)) {
        throw ArgumentError.value(
          id,
          'combinationIds',
          'not unlocked yet, cannot be equipped',
        );
      }
    }
    return AttackLoadout(
      unlockedCombinationIds: unlockedCombinationIds,
      equippedCombinationIds: combinationIds,
    );
  }
}
```

In `packages/battle_engine/lib/battle_engine.dart`, add the export right after `export 'src/discovery_book.dart';`:

```dart
export 'src/discovery_entry.dart';
export 'src/discovery_book.dart';
export 'src/attack_loadout.dart';
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd packages/battle_engine && dart test test/attack_loadout_test.dart`
Expected: PASS (9 tests).

- [ ] **Step 5: Commit**

```bash
git add packages/battle_engine/lib/src/attack_loadout.dart packages/battle_engine/lib/battle_engine.dart packages/battle_engine/test/attack_loadout_test.dart
git commit -m "$(cat <<'EOF'
Adiciona AttackLoadout (Bloco 2c, ataques combinados equipáveis)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: `TrainingProgressStore` ganha ataques desbloqueados/equipados

**Files:**
- Modify: `app/lib/game_domain/training_progress_store.dart`
- Modify: `app/test/game_domain/training_progress_store_test.dart`

**Interfaces:**
- Produces: `loadUnlockedAttackIds(String slot) -> Future<List<String>>`; `saveUnlockedAttackIds(String slot, List<String> ids) -> Future<void>`; `loadEquippedAttackIds(String slot) -> Future<List<String>>`; `saveEquippedAttackIds(String slot, List<String> ids) -> Future<void>`.

- [ ] **Step 1: Write the failing tests**

In `app/test/game_domain/training_progress_store_test.dart`, add a new group at the end of `main()`, right before the closing `}`:

```dart
  group('unlocked attack ids', () {
    test('an empty slot returns an empty list', () async {
      final store = TrainingProgressStore();
      expect(await store.loadUnlockedAttackIds('a'), isEmpty);
    });

    test('saves and reloads a slot', () async {
      final store = TrainingProgressStore();
      await store.saveUnlockedAttackIds('a', ['ignited_storm', 'lava']);

      expect(
        await store.loadUnlockedAttackIds('a'),
        ['ignited_storm', 'lava'],
      );
    });

    test('two slots are independent', () async {
      final store = TrainingProgressStore();
      await store.saveUnlockedAttackIds('a', ['ignited_storm']);
      await store.saveUnlockedAttackIds('b', ['lava']);

      expect(await store.loadUnlockedAttackIds('a'), ['ignited_storm']);
      expect(await store.loadUnlockedAttackIds('b'), ['lava']);
    });
  });

  group('equipped attack ids', () {
    test('an empty slot returns an empty list', () async {
      final store = TrainingProgressStore();
      expect(await store.loadEquippedAttackIds('a'), isEmpty);
    });

    test('saves and reloads a slot', () async {
      final store = TrainingProgressStore();
      await store.saveEquippedAttackIds('a', ['ignited_storm']);

      expect(await store.loadEquippedAttackIds('a'), ['ignited_storm']);
    });

    test('two slots are independent', () async {
      final store = TrainingProgressStore();
      await store.saveEquippedAttackIds('a', ['ignited_storm']);
      await store.saveEquippedAttackIds('b', ['lava']);

      expect(await store.loadEquippedAttackIds('a'), ['ignited_storm']);
      expect(await store.loadEquippedAttackIds('b'), ['lava']);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/game_domain/training_progress_store_test.dart`
Expected: FAIL — the four new methods don't exist yet.

- [ ] **Step 3: Implement the four methods**

In `app/lib/game_domain/training_progress_store.dart`, add two new key prefixes right after `_turnsPlayedKeyPrefix`:

```dart
  static const _unlockedKeyPrefix = 'training_unlocked_';
  static const _discoveredKey = 'training_discovered';
  static const _turnsPlayedKeyPrefix = 'training_turns_played_';
  static const _attacksUnlockedKeyPrefix = 'training_attacks_unlocked_';
  static const _attacksEquippedKeyPrefix = 'training_attacks_equipped_';
```

Add the four new methods at the end of the class, right before the closing `}`:

```dart
  /// Ids das combinações que [slot] já desbloqueou como ataque pessoal
  /// (Bloco 2c) — lista vazia se nunca salvo.
  Future<List<String>> loadUnlockedAttackIds(String slot) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('$_attacksUnlockedKeyPrefix$slot') ?? const [];
  }

  Future<void> saveUnlockedAttackIds(String slot, List<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('$_attacksUnlockedKeyPrefix$slot', ids);
  }

  /// Ids das combinações que [slot] tem equipadas agora (até 3) — lista
  /// vazia se nunca salvo.
  Future<List<String>> loadEquippedAttackIds(String slot) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('$_attacksEquippedKeyPrefix$slot') ?? const [];
  }

  Future<void> saveEquippedAttackIds(String slot, List<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('$_attacksEquippedKeyPrefix$slot', ids);
  }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd app && flutter test test/game_domain/training_progress_store_test.dart`
Expected: PASS (all tests in the file).

- [ ] **Step 5: Commit**

```bash
git add app/lib/game_domain/training_progress_store.dart app/test/game_domain/training_progress_store_test.dart
git commit -m "$(cat <<'EOF'
TrainingProgressStore ganha ataques desbloqueados/equipados (Bloco 2c)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: `TrainingMatch` — gate de ataques equipáveis

**Files:**
- Modify: `app/lib/game_domain/training_match.dart`
- Modify: `app/test/game_domain/training_match_test.dart`

**Interfaces:**
- Consumes: `AttackLoadout` (Task 1).
- Produces: `TrainingMatch({..., AttackLoadout? initialLoadoutA, AttackLoadout? initialLoadoutB})`; `TrainingMatch.fromPersistedProgress({..., required List<String> unlockedAttackIdsA, required List<String> equippedAttackIdsA, required List<String> unlockedAttackIdsB, required List<String> equippedAttackIdsB})`; `String? get lastUnlockedAttackId`; `String? get lastUnlockedAttackName`; `bool get lastUnlockedAttackNeededEquipChoice`; `List<String> get unlockedAttackIdsForPlayerA`; `List<String> get unlockedAttackIdsForPlayerB`; `List<String> get equippedAttackIdsForPlayerA`; `List<String> get equippedAttackIdsForPlayerB`; `void setEquippedAttacks({required bool forPlayerA, required List<String> combinationIds})`; `playElementIds` agora também lança `StateError` para uma combinação já desbloqueada e não equipada.

**Nota de design (achada durante o plano, não estava assim na spec)**:
a spec original propunha `..ForCurrentPlayer` (espelhando
`availableElementIdsForCurrentPlayer` do Bloco 2b). Isso quebra pro
caso de "abrir a tela de Ataques Combinados sozinha ao desbloquear com
vagas cheias" (Task 6): nesse ponto, `playElementIds` **já passou o
turno**, então "o jogador da vez" já é o oponente de quem acabou de
jogar — usar getters/setter "do jogador atual" pegaria os dados
errados. Diferente do gate de AP/elemento bloqueado (que roda **antes**
do turno passar), aqui o consumidor (`TrainingScreen`) sempre precisa
dizer explicitamente qual jogador, então este plano usa só getters/
setter diretos por jogador (`ForPlayerA`/`ForPlayerB`/`forPlayerA:`),
sem nenhuma variante "do jogador atual" pública. `_currentLoadout`
continua existindo, mas como **helper privado**, só usado dentro de
`playElementIds`/`unlockSkillForCurrentPlayer`-style checks que
genuinamente rodam antes do turno passar.

**Ripple esperado**: bem menor que o dos Blocos 2a/2b — nenhum teste existente de `training_match_test.dart` joga a mesma combinação duas vezes para o mesmo jogador (cada teste dispara cada combo no máximo uma vez por jogador), e o auto-equipar cobre exatamente esse caso (com ≤3 combos totais definidos em `default_combinations.dart`, o primeiro disparo de qualquer uma sempre tem vaga livre). Não é esperado ter que ajustar nenhum teste pré-existente neste arquivo — só adicionar os novos.

- [ ] **Step 1: Write the failing tests**

In `app/test/game_domain/training_match_test.dart`, add a new group at the end of `main()`, right before the closing `}` (right after the existing `group('locked elements (Bloco 2b)', ...)`):

```dart
  group('equippable attacks (Bloco 2c)', () {
    test('a combination triggered for the first time is unlocked and '
        'auto-equipped (there is room)', () {
      final match = TrainingMatch(
        initialApA: const ApPool(max: 5, current: 3),
        initialProgressA: _allElementsUnlocked(),
      );

      match.playElementIds(['fire', 'wind']); // Jogador A, Tempestade Ígnea

      expect(match.lastUnlockedAttackId, 'ignited_storm');
      expect(match.lastUnlockedAttackName, 'Tempestade Ígnea');
      expect(match.lastUnlockedAttackNeededEquipChoice, isFalse);
    });

    test('playElementIds throws if the combination is already unlocked '
        'but not equipped', () {
      final match = TrainingMatch(
        initialApA: const ApPool(max: 5, current: 5),
        initialProgressA: _allElementsUnlocked(),
        initialLoadoutA: AttackLoadout(
          unlockedCombinationIds: {'ignited_storm'},
          equippedCombinationIds: const [], // desbloqueado, mas não equipado
        ),
      );

      expect(
        () => match.playElementIds(['fire', 'wind']),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          'Tempestade Ígnea não está equipado. Troque na janela de '
              'Ataques Combinados.',
        )),
      );
    });

    test('playing an equipped combination works normally', () {
      final match = TrainingMatch(
        initialApA: const ApPool(max: 5, current: 3),
        initialProgressA: _allElementsUnlocked(),
        initialLoadoutA: AttackLoadout(
          unlockedCombinationIds: {'ignited_storm'},
          equippedCombinationIds: const ['ignited_storm'],
        ),
      );

      match.playElementIds(['fire', 'wind']);

      expect(match.playerBCurrentHp, equals(80));
      expect(match.lastUnlockedAttackName, isNull); // não é desbloqueio novo
    });

    test('unlocking with 3 slots already full does not auto-equip', () {
      final match = TrainingMatch(
        initialApA: const ApPool(max: 5, current: 5),
        initialProgressA: _allElementsUnlocked(),
        initialLoadoutA: AttackLoadout(
          unlockedCombinationIds: {'a', 'b', 'c'},
          equippedCombinationIds: const ['a', 'b', 'c'],
        ),
      );

      match.playElementIds(['earth', 'fire', 'water']); // Lava, 3º elemento

      expect(match.lastUnlockedAttackId, 'lava');
      expect(match.lastUnlockedAttackNeededEquipChoice, isTrue);
      expect(match.equippedAttackIdsForPlayerA, ['a', 'b', 'c']);
      expect(match.unlockedAttackIdsForPlayerA, contains('lava'));
    });

    test('setEquippedAttacks updates the right player\'s loadout and '
        'propagates AttackLoadout errors', () {
      final match = TrainingMatch(
        initialProgressA: _allElementsUnlocked(),
        initialLoadoutA: AttackLoadout(
          unlockedCombinationIds: {'ignited_storm', 'lava'},
          equippedCombinationIds: const ['ignited_storm'],
        ),
      );

      match.setEquippedAttacks(forPlayerA: true, combinationIds: ['lava']);
      expect(match.equippedAttackIdsForPlayerA, ['lava']);

      expect(
        () => match.setEquippedAttacks(
          forPlayerA: true,
          combinationIds: ['ghost'],
        ),
        throwsArgumentError,
      );
    });

    test('setEquippedAttacks targets Jogador B when forPlayerA is false',
        () {
      final match = TrainingMatch(
        initialProgressB: _allElementsUnlocked(),
        initialLoadoutB: AttackLoadout(
          unlockedCombinationIds: {'ignited_storm', 'lava'},
          equippedCombinationIds: const ['ignited_storm'],
        ),
      );

      match.setEquippedAttacks(forPlayerA: false, combinationIds: ['lava']);

      expect(match.equippedAttackIdsForPlayerB, ['lava']);
      expect(match.equippedAttackIdsForPlayerA, isEmpty); // A não foi tocado
    });

    test('loadout survives startNewBattleKeepingProgress', () {
      final match = TrainingMatch(
        initialApA: const ApPool(max: 5, current: 3),
        initialProgressA: _allElementsUnlocked(),
      );
      match.playElementIds(['fire', 'wind']); // desbloqueia Tempestade Ígnea

      final rematch = match.startNewBattleKeepingProgress();

      expect(rematch.unlockedAttackIdsForPlayerA, ['ignited_storm']);
      expect(rematch.equippedAttackIdsForPlayerA, ['ignited_storm']);
    });

    test('fromPersistedProgress seeds unlocked/equipped attack ids per '
        'player', () {
      final match = TrainingMatch.fromPersistedProgress(
        unlockedNodeIdsA: [],
        unlockedNodeIdsB: [],
        discoveredCombinationIds: [],
        turnsPlayedA: 0,
        turnsPlayedB: 0,
        unlockedAttackIdsA: ['ignited_storm'],
        equippedAttackIdsA: ['ignited_storm'],
        unlockedAttackIdsB: ['lava'],
        equippedAttackIdsB: ['lava'],
      );

      expect(match.unlockedAttackIdsForPlayerA, ['ignited_storm']);
      expect(match.equippedAttackIdsForPlayerA, ['ignited_storm']);
      expect(match.unlockedAttackIdsForPlayerB, ['lava']);
      expect(match.equippedAttackIdsForPlayerB, ['lava']);
    });
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd app && flutter test test/game_domain/training_match_test.dart`
Expected: FAIL — `AttackLoadout` (import ok via barrel, but) `initialLoadoutA`, `lastUnlockedAttackId`, etc. don't exist yet on `TrainingMatch`; `fromPersistedProgress` doesn't accept the 4 new required params yet.

- [ ] **Step 3: Implement the changes in `training_match.dart`**

Add the import (already covered — `AttackLoadout` comes from the existing `import 'package:battle_engine/battle_engine.dart';`).

Add two new fields right after `_progressB`:

```dart
  late SkillProgress _progressA;
  late SkillProgress _progressB;
  late AttackLoadout _loadoutA;
  late AttackLoadout _loadoutB;
  late int _cumulativeTurnsA;
  late int _cumulativeTurnsB;
```

Add two new `String?`/`bool` fields right after `_lastAppliedStatusNames`:

```dart
  String? _lastTriggeredCombinationName;
  List<String> _lastAppliedStatusNames = [];
  String? _lastUnlockedAttackId;
  String? _lastUnlockedAttackName;
  bool _lastUnlockedAttackNeededEquipChoice = false;
  int _turnsPlayed = 0;
```

Update the constructor:

```dart
  TrainingMatch({
    SkillProgress? initialProgressA,
    SkillProgress? initialProgressB,
    DiscoveryBook? initialDiscoveryBook,
    ApPool? initialApA,
    ApPool? initialApB,
    int initialTurnsPlayedA = 0,
    int initialTurnsPlayedB = 0,
    AttackLoadout? initialLoadoutA,
    AttackLoadout? initialLoadoutB,
  }) {
    _progressA = initialProgressA ?? SkillProgress(defaultSkillTree);
    _progressB = initialProgressB ?? SkillProgress(defaultSkillTree);
    _discoveryBook = initialDiscoveryBook ?? DiscoveryBook();
    _cumulativeTurnsA = initialTurnsPlayedA;
    _cumulativeTurnsB = initialTurnsPlayedB;
    _loadoutA = initialLoadoutA ?? AttackLoadout();
    _loadoutB = initialLoadoutB ?? AttackLoadout();
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
```

(Adicione a linha do doc comment do construtor mencionando os dois
parâmetros novos, junto das outras já documentadas ali — mesmo estilo
das anteriores: "`[initialLoadoutA]`/`[initialLoadoutB]` seedam os
ataques já desbloqueados/equipados de cada jogador (Bloco 2c), default
`AttackLoadout()` vazio.")

Update `fromPersistedProgress`:

```dart
  factory TrainingMatch.fromPersistedProgress({
    required List<String> unlockedNodeIdsA,
    required List<String> unlockedNodeIdsB,
    required List<String> discoveredCombinationIds,
    required int turnsPlayedA,
    required int turnsPlayedB,
    required List<String> unlockedAttackIdsA,
    required List<String> equippedAttackIdsA,
    required List<String> unlockedAttackIdsB,
    required List<String> equippedAttackIdsB,
  }) {
    return TrainingMatch(
      initialProgressA: SkillProgress(defaultSkillTree, unlockedNodeIds: unlockedNodeIdsA),
      initialProgressB: SkillProgress(defaultSkillTree, unlockedNodeIds: unlockedNodeIdsB),
      initialDiscoveryBook: DiscoveryBook(discoveredCombinationIds: discoveredCombinationIds.toSet()),
      initialTurnsPlayedA: turnsPlayedA,
      initialTurnsPlayedB: turnsPlayedB,
      initialLoadoutA: AttackLoadout(
        unlockedCombinationIds: unlockedAttackIdsA.toSet(),
        equippedCombinationIds: equippedAttackIdsA,
      ),
      initialLoadoutB: AttackLoadout(
        unlockedCombinationIds: unlockedAttackIdsB.toSet(),
        equippedCombinationIds: equippedAttackIdsB,
      ),
    );
  }
```

Update `startNewBattleKeepingProgress`:

```dart
  TrainingMatch startNewBattleKeepingProgress() {
    return TrainingMatch(
      initialProgressA: _progressA,
      initialProgressB: _progressB,
      initialDiscoveryBook: _discoveryBook,
      initialTurnsPlayedA: _cumulativeTurnsA,
      initialTurnsPlayedB: _cumulativeTurnsB,
      initialLoadoutA: _loadoutA,
      initialLoadoutB: _loadoutB,
    );
  }
```

Add `_currentLoadout` right after `_currentProgress`:

```dart
  SkillProgress get _currentProgress =>
      _isPlayerATurn ? _progressA : _progressB;

  AttackLoadout get _currentLoadout =>
      _isPlayerATurn ? _loadoutA : _loadoutB;
```

Add the getters, right after `availableElementIdsForCurrentPlayer` (Bloco 2b):

```dart
  /// Element ids the player whose turn it currently is can play with —
  /// used by the element picker to know which chips are selectable
  /// (Bloco 2b).
  List<String> get availableElementIdsForCurrentPlayer =>
      _currentProgress.grantedElementIds;

  /// Id/nome do combo que a jogada mais recente desbloqueou pela
  /// primeira vez — `null` se a jogada mais recente não desbloqueou
  /// nada novo (Bloco 2c).
  String? get lastUnlockedAttackId => _lastUnlockedAttackId;
  String? get lastUnlockedAttackName => _lastUnlockedAttackName;

  /// `true` só quando a jogada mais recente desbloqueou um combo novo
  /// e as 3 vagas de equipados já estavam cheias (o novo ficou
  /// desbloqueado, mas não equipado) — sinaliza que a UI precisa abrir
  /// a tela de troca.
  bool get lastUnlockedAttackNeededEquipChoice =>
      _lastUnlockedAttackNeededEquipChoice;

  /// Ids das combinações que Jogador A/B já desbloquearam como ataque
  /// pessoal (Bloco 2c) — diretos por jogador, não "do jogador da vez
  /// atual": depois que [playElementIds] passa o turno, "o jogador da
  /// vez" já é o oponente de quem acabou de jogar, então quem chama
  /// (`TrainingScreen`) sempre precisa dizer explicitamente qual
  /// jogador quer (mesmo motivo de `cumulativeTurnsPlayedA`/`B`, Bloco
  /// 2b) — usados tanto pra montar a tela de Ataques Combinados quanto
  /// pra salvar o progresso de quem acabou de jogar.
  List<String> get unlockedAttackIdsForPlayerA =>
      _loadoutA.unlockedCombinationIds.toList();
  List<String> get unlockedAttackIdsForPlayerB =>
      _loadoutB.unlockedCombinationIds.toList();

  /// Ids das combinações que Jogador A/B têm equipadas agora (até 3).
  List<String> get equippedAttackIdsForPlayerA => _loadoutA.equippedCombinationIds;
  List<String> get equippedAttackIdsForPlayerB => _loadoutB.equippedCombinationIds;

  /// Substitui os ataques equipados de [forPlayerA] (`true` = Jogador
  /// A, `false` = Jogador B) — explícito, não "do jogador da vez",
  /// pelo mesmo motivo dos getters acima (quem chama pode estar
  /// gerenciando o ataque de um jogador cujo turno já passou). Lança
  /// `ArgumentError` se passar mais de 3 ids, ou algum id que esse
  /// jogador ainda não desbloqueou (ver `AttackLoadout.withEquipped`).
  void setEquippedAttacks({
    required bool forPlayerA,
    required List<String> combinationIds,
  }) {
    final current = forPlayerA ? _loadoutA : _loadoutB;
    final updated = current.withEquipped(combinationIds);
    if (forPlayerA) {
      _loadoutA = updated;
    } else {
      _loadoutB = updated;
    }
  }
```

Update `playElementIds` — adicionar a checagem de "combo desbloqueado
mas não equipado" logo depois da checagem de elemento bloqueado
(Bloco 2b) e antes de montar a `Ability`, e atualizar o loadout depois
que `useAbility` retorna:

```dart
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

    final loadoutBeforeThisPlay = _currentLoadout;
    if (elementIds.length >= 2) {
      final knownCombo = defaultCombinationBook.resolve(elements);
      if (knownCombo != null &&
          loadoutBeforeThisPlay.isUnlocked(knownCombo.resultId) &&
          !loadoutBeforeThisPlay.isEquipped(knownCombo.resultId)) {
        throw StateError(
          '${knownCombo.resultName} não está equipado. Troque na '
          'janela de Ataques Combinados.',
        );
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

      final comboId = result.triggeredCombination!.resultId;
      final wasNewlyUnlocked = !loadoutBeforeThisPlay.isUnlocked(comboId);
      final updatedLoadout = loadoutBeforeThisPlay.withUnlocked(comboId);
      if (wasPlayerATurn) {
        _loadoutA = updatedLoadout;
      } else {
        _loadoutB = updatedLoadout;
      }
      if (wasNewlyUnlocked) {
        _lastUnlockedAttackId = comboId;
        _lastUnlockedAttackName = result.triggeredCombination!.resultName;
        _lastUnlockedAttackNeededEquipChoice =
            loadoutBeforeThisPlay.equippedCombinationIds.length == 3;
      } else {
        _lastUnlockedAttackId = null;
        _lastUnlockedAttackName = null;
        _lastUnlockedAttackNeededEquipChoice = false;
      }
    } else {
      _lastUnlockedAttackId = null;
      _lastUnlockedAttackName = null;
      _lastUnlockedAttackNeededEquipChoice = false;
    }
    _turnsPlayed++;
    if (wasPlayerATurn) {
      _cumulativeTurnsA++;
    } else {
      _cumulativeTurnsB++;
    }
  }
```

(Atualize também o doc comment de `playElementIds`, acrescentando uma
frase sobre o novo `StateError` de "não está equipado", junto do que
já documenta o `StateError` de AP insuficiente.)

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd app && flutter test test/game_domain/training_match_test.dart`
Expected: PASS (todos os testes do arquivo, incluindo o novo `group('equippable attacks (Bloco 2c)', ...)`).

- [ ] **Step 5: Run the whole app suite to confirm the ripple is as small as expected**

Run: `cd app && flutter test`
Expected: as únicas falhas devem ser em `test/training_screen_test.dart` (por causa de `fromPersistedProgress` agora exigir os 4 parâmetros novos, quebrando a compilação de `training_screen.dart` — mesma cascata que aconteceu no Bloco 2b até a Task de wiring da tela). Nenhum outro arquivo deveria falhar. Não tente consertar `training_screen_test.dart` aqui — a Task 6 cuida disso.

- [ ] **Step 6: Commit**

```bash
git add app/lib/game_domain/training_match.dart app/test/game_domain/training_match_test.dart
git commit -m "$(cat <<'EOF'
TrainingMatch ganha gate de ataques equipáveis (Bloco 2c)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Catálogo de ataques pra exibição

**Files:**
- Create: `app/lib/game_domain/attack_catalog.dart`
- Create: `app/test/game_domain/attack_catalog_test.dart`

**Interfaces:**
- Produces: `class AttackOption { String id; String name; String description; bool unlocked; bool equipped; }`; `List<AttackOption> allAttackOptions({required List<String> unlockedIds, required List<String> equippedIds})`.

- [ ] **Step 1: Write the failing test**

Create `app/test/game_domain/attack_catalog_test.dart`:

```dart
import 'package:app/game_domain/attack_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('allAttackOptions lists every known combination with display info', () {
    final options = allAttackOptions(unlockedIds: const [], equippedIds: const []);

    expect(options, isNotEmpty);
    final stormOption = options.firstWhere((o) => o.id == 'ignited_storm');
    expect(stormOption.name, 'Tempestade Ígnea');
    expect(stormOption.unlocked, isFalse);
    expect(stormOption.equipped, isFalse);
  });

  test('allAttackOptions marks unlocked/equipped ids correctly', () {
    final options = allAttackOptions(
      unlockedIds: const ['ignited_storm'],
      equippedIds: const ['ignited_storm'],
    );

    final stormOption = options.firstWhere((o) => o.id == 'ignited_storm');
    expect(stormOption.unlocked, isTrue);
    expect(stormOption.equipped, isTrue);

    final otherOption = options.firstWhere((o) => o.id != 'ignited_storm');
    expect(otherOption.unlocked, isFalse);
    expect(otherOption.equipped, isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/game_domain/attack_catalog_test.dart`
Expected: FAIL — `attack_catalog.dart` doesn't exist yet.

- [ ] **Step 3: Implement `attack_catalog.dart`**

Create `app/lib/game_domain/attack_catalog.dart`:

```dart
import 'package:battle_engine/battle_engine.dart';

/// Game Domain's own value type for a combination shown as an
/// equippable "attack" (Bloco 2c) — UI never names `ElementCombination`
/// directly (DECISION-011/017).
class AttackOption {
  final String id;
  final String name;
  final String description;
  final bool unlocked;
  final bool equipped;

  const AttackOption({
    required this.id,
    required this.name,
    required this.description,
    required this.unlocked,
    required this.equipped,
  });
}

/// Todas as combinações de `defaultCombinationBook`, marcadas com o
/// que um jogador específico já desbloqueou/equipou — quem chama
/// decide se esconde as entradas ainda não desbloqueadas (ver
/// `attacks_screen.dart`).
List<AttackOption> allAttackOptions({
  required List<String> unlockedIds,
  required List<String> equippedIds,
}) {
  return defaultCombinationBook.combinations
      .map((combo) => AttackOption(
            id: combo.resultId,
            name: combo.resultName,
            description: combo.description,
            unlocked: unlockedIds.contains(combo.resultId),
            equipped: equippedIds.contains(combo.resultId),
          ))
      .toList();
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/game_domain/attack_catalog_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add app/lib/game_domain/attack_catalog.dart app/test/game_domain/attack_catalog_test.dart
git commit -m "$(cat <<'EOF'
Adiciona attack_catalog.dart (Bloco 2c)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: Tela "Ataques Combinados"

**Files:**
- Create: `app/lib/ui/attacks_screen.dart`
- Create: `app/test/attacks_screen_test.dart`

**Interfaces:**
- Consumes: `AttackOption`, `allAttackOptions` (Task 4).
- Produces: `class AttacksScreen extends StatefulWidget { const AttacksScreen({required List<AttackOption> attacks, required Future<String?> Function(List<String>) onSetEquipped, String? highlightComboId}); }`.

- [ ] **Step 1: Write the failing tests**

Create `app/test/attacks_screen_test.dart`:

```dart
import 'package:app/game_domain/attack_catalog.dart';
import 'package:app/ui/attacks_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _storm = AttackOption(
  id: 'ignited_storm',
  name: 'Tempestade Ígnea',
  description: 'Fogo espalhado pelo vento; dano em área.',
  unlocked: true,
  equipped: false,
);
const _field = AttackOption(
  id: 'electrified_field',
  name: 'Campo Eletrocutado',
  description: 'Água carregada de eletricidade; choca quem entrar no campo.',
  unlocked: true,
  equipped: false,
);
const _lockedLava = AttackOption(
  id: 'lava',
  name: 'Lava',
  description: 'Terra fundida pelo fogo; terreno perigoso e persistente.',
  unlocked: false,
  equipped: false,
);

void main() {
  testWidgets('lists only unlocked attacks', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AttacksScreen(
        attacks: [_storm, _lockedLava],
        onSetEquipped: (_) async => null,
      ),
    ));
    await tester.pump();

    expect(find.text('Tempestade Ígnea'), findsOneWidget);
    expect(find.text('Lava'), findsNothing);
  });

  testWidgets('tapping a non-equipped attack with room equips it directly',
      (tester) async {
    List<String>? sentIds;
    await tester.pumpWidget(MaterialApp(
      home: AttacksScreen(
        attacks: [_storm],
        onSetEquipped: (ids) async {
          sentIds = ids;
          return null;
        },
      ),
    ));
    await tester.pump();

    await tester.tap(find.text('Tempestade Ígnea'));
    await tester.pump();

    expect(sentIds, ['ignited_storm']);
  });

  testWidgets(
      'tapping a non-equipped attack with 3 already equipped opens a swap '
      'picker', (tester) async {
    const equippedA = AttackOption(
      id: 'a',
      name: 'A',
      description: 'x',
      unlocked: true,
      equipped: true,
    );
    const equippedB = AttackOption(
      id: 'b',
      name: 'B',
      description: 'x',
      unlocked: true,
      equipped: true,
    );
    const equippedC = AttackOption(
      id: 'c',
      name: 'C',
      description: 'x',
      unlocked: true,
      equipped: true,
    );
    List<String>? sentIds;
    await tester.pumpWidget(MaterialApp(
      home: AttacksScreen(
        attacks: [equippedA, equippedB, equippedC, _storm],
        onSetEquipped: (ids) async {
          sentIds = ids;
          return null;
        },
      ),
    ));
    await tester.pump();

    await tester.tap(find.text('Tempestade Ígnea'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // O seletor de troca lista os 3 atualmente equipados.
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('C'), findsOneWidget);

    await tester.tap(find.text('B'));
    await tester.pump();

    expect(sentIds, containsAll(['a', 'c', 'ignited_storm']));
    expect(sentIds, isNot(contains('b')));
    expect(sentIds!.length, 3);
  });

  testWidgets('tapping an equipped attack offers to unequip it',
      (tester) async {
    const equipped = AttackOption(
      id: 'ignited_storm',
      name: 'Tempestade Ígnea',
      description: 'x',
      unlocked: true,
      equipped: true,
    );
    List<String>? sentIds;
    await tester.pumpWidget(MaterialApp(
      home: AttacksScreen(
        attacks: [equipped],
        onSetEquipped: (ids) async {
          sentIds = ids;
          return null;
        },
      ),
    ));
    await tester.pump();

    await tester.tap(find.text('Tempestade Ígnea'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Desequipar'));
    await tester.pump();

    expect(sentIds, isEmpty);
  });

  testWidgets(
      'highlightComboId opens the swap picker automatically when slots are '
      'full', (tester) async {
    const equippedA = AttackOption(
      id: 'a',
      name: 'A',
      description: 'x',
      unlocked: true,
      equipped: true,
    );
    const equippedB = AttackOption(
      id: 'b',
      name: 'B',
      description: 'x',
      unlocked: true,
      equipped: true,
    );
    const equippedC = AttackOption(
      id: 'c',
      name: 'C',
      description: 'x',
      unlocked: true,
      equipped: true,
    );
    await tester.pumpWidget(MaterialApp(
      home: AttacksScreen(
        attacks: [equippedA, equippedB, equippedC, _storm],
        onSetEquipped: (_) async => null,
        highlightComboId: 'ignited_storm',
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.textContaining('substituir por Tempestade Ígnea'),
      findsOneWidget,
    );
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd app && flutter test test/attacks_screen_test.dart`
Expected: FAIL — `attacks_screen.dart` doesn't exist yet.

- [ ] **Step 3: Implement `AttacksScreen`**

Create `app/lib/ui/attacks_screen.dart`:

```dart
import 'package:flutter/material.dart';

import '../game_domain/attack_catalog.dart';
import '../game_presentation/pixel_arena_background.dart';
import '../game_presentation/pixel_content_panel.dart';
import '../game_presentation/pixel_menu_button.dart';
import '../game_presentation/pixel_outlined_text.dart';
import '../game_presentation/pixel_sheet_panel.dart';

/// Tela cheia listando os ataques (combinações) que o jogador da vez já
/// desbloqueou, com os até 3 equipados em destaque — permite equipar,
/// desequipar e trocar (Bloco 2c, DECISION-048). A tela não muda estado
/// de `TrainingMatch` sozinha — chama [onSetEquipped] (o chamador decide
/// como aplicar e persistir), mesmo padrão de `SkillTreeScreen.onUnlock`.
/// Ver docs/superpowers/specs/2026-09-15-equippable-attacks-design.md.
class AttacksScreen extends StatefulWidget {
  const AttacksScreen({
    super.key,
    required this.attacks,
    required this.onSetEquipped,
    this.highlightComboId,
  });

  final List<AttackOption> attacks;
  final Future<String?> Function(List<String> combinationIds) onSetEquipped;
  final String? highlightComboId;

  @override
  State<AttacksScreen> createState() => _AttacksScreenState();
}

class _AttacksScreenState extends State<AttacksScreen> {
  late List<AttackOption> _attacks = widget.attacks;

  List<AttackOption> get _unlockedAttacks =>
      _attacks.where((a) => a.unlocked).toList();

  List<String> get _equippedIds =>
      _attacks.where((a) => a.equipped).map((a) => a.id).toList();

  @override
  void initState() {
    super.initState();
    final highlightId = widget.highlightComboId;
    if (highlightId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final highlighted = _attacks.firstWhere((a) => a.id == highlightId);
        _openAttackAction(highlighted);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final unlocked = _unlockedAttacks;
    return Stack(
      children: [
        Positioned.fill(child: CustomPaint(painter: ArenaBackdropPainter())),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const PixelOutlinedText('Ataques Combinados', fontSize: 20),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: PixelContentPanel(
              child: unlocked.isEmpty
                  ? const Text('Nenhum ataque desbloqueado ainda.')
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final attack in unlocked)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _AttackTile(
                                attack: attack,
                                onTap: () => _openAttackAction(attack),
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

  void _openAttackAction(AttackOption attack) {
    if (attack.equipped) {
      _showUnequipSheet(attack);
    } else if (_equippedIds.length < 3) {
      _setEquipped([..._equippedIds, attack.id]);
    } else {
      _showSwapSheet(attack);
    }
  }

  void _showUnequipSheet(AttackOption attack) {
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
                PixelOutlinedText(attack.name, fontSize: 18),
                const SizedBox(height: 8),
                Text(attack.description),
                const SizedBox(height: 12),
                PixelMenuButton(
                  label: 'Desequipar',
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    _setEquipped(
                      _equippedIds.where((id) => id != attack.id).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSwapSheet(AttackOption newAttack) {
    final equippedIds = _equippedIds;
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
                PixelOutlinedText(
                  'Escolha um ataque pra substituir por ${newAttack.name}',
                  fontSize: 16,
                ),
                const SizedBox(height: 12),
                for (final equippedId in equippedIds)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: PixelMenuButton(
                      label: _attacks.firstWhere((a) => a.id == equippedId).name,
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        _setEquipped([
                          for (final id in equippedIds)
                            if (id != equippedId) id,
                          newAttack.id,
                        ]);
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _setEquipped(List<String> ids) async {
    final error = await widget.onSetEquipped(ids);
    if (error != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    if (!mounted) return;
    setState(() {
      _attacks = [
        for (final attack in _attacks)
          AttackOption(
            id: attack.id,
            name: attack.name,
            description: attack.description,
            unlocked: attack.unlocked,
            equipped: ids.contains(attack.id),
          ),
      ];
    });
  }
}

class _AttackTile extends StatelessWidget {
  const _AttackTile({required this.attack, required this.onTap});

  final AttackOption attack;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: attack.equipped ? const Color(0xFFF4C94A) : const Color(0xFFF4F4E4),
          border: Border.all(color: const Color(0xFF2B2B2B), width: 3),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          attack.equipped ? '${attack.name} (equipado)' : attack.name,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 14,
            color: Color(0xFF2B2B2B),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd app && flutter test test/attacks_screen_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add app/lib/ui/attacks_screen.dart app/test/attacks_screen_test.dart
git commit -m "$(cat <<'EOF'
Adiciona AttacksScreen — gerenciar ataques equipados (Bloco 2c)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: Fiação na `TrainingScreen`

**Files:**
- Modify: `app/lib/ui/training_screen.dart`
- Modify: `app/test/training_screen_test.dart`

**Interfaces:**
- Consumes: `AttacksScreen` (Task 5), `allAttackOptions` (Task 4), `TrainingMatch.lastUnlockedAttackId`/`lastUnlockedAttackName`/`lastUnlockedAttackNeededEquipChoice`/`unlockedAttackIdsForPlayerA`/`B`/`equippedAttackIdsForPlayerA`/`B`/`setEquippedAttacks`/`fromPersistedProgress` com os 4 params novos (Task 3), `TrainingProgressStore.loadUnlockedAttackIds`/`saveUnlockedAttackIds`/`loadEquippedAttackIds`/`saveEquippedAttackIds` (Task 2).

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
      expect(
        find.textContaining('Novo ataque desbloqueado: Tempestade Ígnea'),
        findsOneWidget,
      );
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

  testWidgets(
    'rejects replaying a discovered-but-unequipped combination with a '
    'friendly message',
    (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: TrainingScreen(
          initialMatch: TrainingMatch(
            initialApA: const ApPool(max: 5, current: 5),
            initialProgressA: _allElementsUnlocked(),
            initialLoadoutA: AttackLoadout(
              unlockedCombinationIds: const {'ignited_storm'},
              equippedCombinationIds: const [], // desbloqueado, não equipado
            ),
          ),
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

      expect(
        find.text(
          'Tempestade Ígnea não está equipado. Troque na janela de '
          'Ataques Combinados.',
        ),
        findsOneWidget,
      );
      expect(find.text('Vez de: Jogador A'), findsOneWidget); // turno não passou
    },
  );

  testWidgets(
    'opens Ataques Combinados automatically when unlocking with 3 slots '
    'already full',
    (WidgetTester tester) async {
      // O jogo só define 3 combinações reais hoje (ignited_storm,
      // electrified_field, lava) — não dá pra encher 3 vagas com
      // combos reais e ainda sobrar um 4º real pra descobrir. Os 2
      // ids "fake_a"/"fake_b" preenchem 2 das 3 vagas de propósito
      // (`AttackLoadout` não valida que um id equipado corresponda a
      // uma `ElementCombination` real — é só contagem); a 3ª vaga é
      // preenchida com "electrified_field" (também não jogado nesta
      // partida) só pra reduzir o que aparece de "ruído" na tela. O
      // que este teste verifica é só a navegação (TrainingScreen abre
      // AttacksScreen sozinha) — o conteúdo exato do seletor de troca
      // já é coberto por `attacks_screen_test.dart` (Task 5).
      await tester.pumpWidget(MaterialApp(
        home: TrainingScreen(
          initialMatch: TrainingMatch(
            initialApA: const ApPool(max: 5, current: 5),
            initialProgressA: _allElementsUnlocked(),
            initialLoadoutA: AttackLoadout(
              unlockedCombinationIds: const {
                'electrified_field',
                'fake_a',
                'fake_b',
              },
              equippedCombinationIds: const [
                'electrified_field',
                'fake_a',
                'fake_b',
              ],
            ),
          ),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('Escolher elementos'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('🪨 Terra'));
      await tester.pump();
      await tester.tap(find.text('🔥 Fogo'));
      await tester.pump();
      await tester.tap(find.text('💧 Água'));
      await tester.pump();

      await tester.tap(find.text('Confirmar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.ensureVisible(find.text('Jogar'));
      await tester.tap(find.text('Jogar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Ataques Combinados'), findsOneWidget);
    },
  );
}
```

- [ ] **Step 2: Run tests to verify the expected failures**

Run: `cd app && flutter test test/training_screen_test.dart`
Expected: FAIL — `training_screen.dart` ainda não compila com os 4 novos parâmetros required de `fromPersistedProgress`, e os testes novos referenciam `AttackLoadout`/comportamento que ainda não existe na tela.

- [ ] **Step 3: Wire up `training_screen.dart`**

Add two new imports, right after `import 'element_starter_screen.dart';`:

```dart
import '../game_domain/attack_catalog.dart';
import 'attacks_screen.dart';
import 'element_starter_screen.dart';
import 'skill_tree_screen.dart';
```

Add new instance fields, right after `int _turnsPlayedB = 0;`:

```dart
  int _turnsPlayedA = 0;
  int _turnsPlayedB = 0;
  List<String> _unlockedAttacksA = [];
  List<String> _equippedAttacksA = [];
  List<String> _unlockedAttacksB = [];
  List<String> _equippedAttacksB = [];
  final Set<String> _selectedIds = {};
  String? _error;
  String? _lastUnlockedAttackText;
  AttackEvent? _pendingAttack;
```

Update `_loadPersistedMatch` to also load the 4 new lists:

```dart
  Future<void> _loadPersistedMatch() async {
    _unlockedA = await _progressStore.loadUnlockedNodeIds('a');
    _unlockedB = await _progressStore.loadUnlockedNodeIds('b');
    _discovered = await _progressStore.loadDiscoveredCombinationIds();
    _turnsPlayedA = await _progressStore.loadTurnsPlayed('a');
    _turnsPlayedB = await _progressStore.loadTurnsPlayed('b');
    _unlockedAttacksA = await _progressStore.loadUnlockedAttackIds('a');
    _equippedAttacksA = await _progressStore.loadEquippedAttackIds('a');
    _unlockedAttacksB = await _progressStore.loadUnlockedAttackIds('b');
    _equippedAttacksB = await _progressStore.loadEquippedAttackIds('b');
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
```

Update `_buildMatchFromLoadedProgress` to pass the 4 new required params:

```dart
  void _buildMatchFromLoadedProgress() {
    setState(() {
      _match = TrainingMatch.fromPersistedProgress(
        unlockedNodeIdsA: _unlockedA,
        unlockedNodeIdsB: _unlockedB,
        discoveredCombinationIds: _discovered,
        turnsPlayedA: _turnsPlayedA,
        turnsPlayedB: _turnsPlayedB,
        unlockedAttackIdsA: _unlockedAttacksA,
        equippedAttackIdsA: _equippedAttacksA,
        unlockedAttackIdsB: _unlockedAttacksB,
        equippedAttackIdsB: _equippedAttacksB,
      );
      _pendingOnboardingSlot = null;
      _loading = false;
    });
  }
```

Update `_playTurn` to save attack ids and set `_lastUnlockedAttackText` /
open `AttacksScreen` automatically:

Nota: `wasPlayerATurn` precisa ser capturado **fora** do `setState`
(não só dentro dele, como no Bloco 2b), porque agora é usado também
**depois** que o `setState` fecha — pra decidir de quem é o
`AttacksScreen` que abre automaticamente.

```dart
  void _playTurn() {
    final wasPlayerATurn = _match.isPlayerATurn;
    setState(() {
      _error = null;
      _lastUnlockedAttackText = null;
      final playedElementIds = _selectedIds.toList();
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
        if (_match.lastUnlockedAttackName != null) {
          final slot = wasPlayerATurn ? 'a' : 'b';
          final unlockedIds = wasPlayerATurn
              ? _match.unlockedAttackIdsForPlayerA
              : _match.unlockedAttackIdsForPlayerB;
          final equippedIds = wasPlayerATurn
              ? _match.equippedAttackIdsForPlayerA
              : _match.equippedAttackIdsForPlayerB;
          unawaited(_progressStore.saveUnlockedAttackIds(slot, unlockedIds));
          unawaited(_progressStore.saveEquippedAttackIds(slot, equippedIds));
          if (!_match.lastUnlockedAttackNeededEquipChoice) {
            _lastUnlockedAttackText =
                'Novo ataque desbloqueado: ${_match.lastUnlockedAttackName}! '
                '(equipado automaticamente)';
          }
        }
        if (_match.isOver) {
          sfxPlayer.play(SfxId.victory);
        }
      } on ArgumentError {
        _error = 'Jogada inválida.';
      } on StateError catch (e) {
        _error = e.message.contains('não está equipado')
            ? e.message
            : 'AP insuficiente para essa combinação.';
      }
    });
    if (_match.lastUnlockedAttackNeededEquipChoice) {
      unawaited(_openAttacksScreen(
        forPlayerA: wasPlayerATurn,
        highlightComboId: _match.lastUnlockedAttackId,
      ));
    }
  }
```

**Atenção nesse passo**: o `catch` de `StateError` hoje (Bloco 2a)
sempre define `_error = 'AP insuficiente para essa combinação.'`, sem
olhar a mensagem — porque até agora só existia um tipo de
`StateError`. Agora existem dois motivos possíveis (AP insuficiente,
vindo de `TurnEngine`, mensagem em inglês; combo não equipado, vindo
de `TrainingMatch`, mensagem já em português). A lógica acima checa se
a mensagem já é a de "não está equipado" (está em português, criada
por `TrainingMatch`) e usa ela direto; senão, assume que é o erro de
AP (mensagem em inglês do `battle_engine`, nunca mostrada crua) e usa
o texto fixo em português de sempre. Substitua o bloco `on StateError`
inteiro pelo texto acima — não é um placeholder, é a lógica real.

Add the new private method `_openAttacksScreen`, right after
`_openSkillTree`. **Importante**: recebe `forPlayerA` explícito, não
lê `_match.isPlayerATurn` internamente — porque o chamador do fluxo de
"acabou de desbloquear" (`_playTurn`) já passou o turno no momento em
que chama isso, então "o jogador da vez atual" seria o errado (ver a
nota de design da Task 3). O botão manual da AppBar passa
`_match.isPlayerATurn` explicitamente (correto nesse caso, já que
equipar/desequipar não passa turno) — os dois pontos de entrada
continuam corretos porque cada um decide o valor certo pra si:

```dart
  Future<void> _openAttacksScreen({
    required bool forPlayerA,
    String? highlightComboId,
  }) async {
    final unlockedIds = forPlayerA
        ? _match.unlockedAttackIdsForPlayerA
        : _match.unlockedAttackIdsForPlayerB;
    final equippedIds = forPlayerA
        ? _match.equippedAttackIdsForPlayerA
        : _match.equippedAttackIdsForPlayerB;
    await Navigator.of(context).push(pixelSlideRoute((_) => AttacksScreen(
      attacks: allAttackOptions(unlockedIds: unlockedIds, equippedIds: equippedIds),
      highlightComboId: highlightComboId,
      onSetEquipped: (ids) async {
        try {
          _match.setEquippedAttacks(forPlayerA: forPlayerA, combinationIds: ids);
          final slot = forPlayerA ? 'a' : 'b';
          unawaited(_progressStore.saveEquippedAttackIds(slot, ids));
          return null;
        } on ArgumentError catch (e) {
          return e.message;
        }
      },
    )));
    setState(() {});
  }
```

Add a second `IconButton` to the AppBar's `actions`, right after the
Habilidades one:

```dart
            actions: [
              IconButton(
                icon: const Icon(Icons.auto_awesome),
                tooltip: 'Habilidades',
                onPressed: _openSkillTree,
              ),
              IconButton(
                icon: const Icon(Icons.flash_on),
                tooltip: 'Ataques Combinados',
                onPressed: () => _openAttacksScreen(forPlayerA: _match.isPlayerATurn),
              ),
            ],
```

Show `_lastUnlockedAttackText` inline, right after the existing
"Efeitos aplicados" block (inside `build`'s `Column`):

```dart
                  if (_match.lastAppliedStatusNames.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Efeitos aplicados: ${_match.lastAppliedStatusNames.join(", ")}',
                      ),
                    ),
                  if (_lastUnlockedAttackText != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(_lastUnlockedAttackText!),
                    ),
                  const Divider(height: 32),
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd app && flutter test test/training_screen_test.dart`
Expected: PASS (todos os testes do arquivo, incluindo os 3 novos).

- [ ] **Step 5: Run the whole app suite and analyze**

Run: `cd app && flutter test && flutter analyze`
Expected: todos os testes PASS, `No issues found!`.

- [ ] **Step 6: Commit**

```bash
git add app/lib/ui/training_screen.dart app/test/training_screen_test.dart
git commit -m "$(cat <<'EOF'
Fia a tela de Ataques Combinados na TrainingScreen (Bloco 2c)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: Suíte completa, verificação manual e documentação

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

Reiniciar o preview com `preview_stop` + `preview_start` completo (nunca
só recarregar). No Modo Treino, com progresso já suficiente (ex: usar
`localStorage` de uma sessão anterior desta mesma máquina, ou passar
pela escolha inicial de novo):

- Disparar uma combinação pela primeira vez com vaga livre — confirmar
  que aparece "Novo ataque desbloqueado: X! (equipado automaticamente)"
  inline, sem abrir nenhuma tela nova.
- Abrir "Ataques Combinados" pelo ícone novo na AppBar — confirmar que
  lista o ataque recém-desbloqueado, marcado como equipado.
- Desequipar esse ataque manualmente na tela.
- Voltar e tentar montar a mesma combinação de novo escolhendo os
  elementos manualmente — confirmar que aparece a mensagem "X não está
  equipado. Troque na janela de Ataques Combinados." e o turno não
  passa.
- Descobrir combinações suficientes pra encher as 3 vagas, depois
  disparar uma 4ª ainda não vista — confirmar que a tela de Ataques
  Combinados abre sozinha, mostrando o seletor de troca.
- Nenhum erro no console do navegador.

- [ ] **Step 4: Registrar DECISION-048 em `DECISIONS.md`**

Ler `DECISIONS.md`, localizar a última entrada (`DECISION-047`), e
adicionar uma nova entrada `DECISION-048` logo depois, cobrindo:
- Bloco 2c (sequência combinada com o usuário desde o Bloco 2a):
  combinações disparadas pela primeira vez viram "ataques" pessoais
  por jogador — `AttackLoadout` (novo, `battle_engine`, separado do
  `DiscoveryBook` compartilhado que não muda), até 3 equipados por
  jogador. Vaga livre no desbloqueio equipa automático; vagas cheias
  abre a tela "Ataques Combinados" na hora, pedindo a troca. A partir
  do desbloqueio, só dá pra rejogar a combinação se estiver equipada —
  tentar sem equipar é rejeitado (`StateError`, mesmo padrão de "AP
  insuficiente"/"elemento bloqueado").
- Só Modo Treino — Multiplayer aguarda o Bloco 11.
- Nada neste bloco toca `BattleState`/`TurnEngine`/backend — o gate
  vive inteiramente em `TrainingMatch`.
- Diferente dos Blocos 2a/2b, o ripple em testes pré-existentes foi
  mínimo — nenhum teste de `training_match_test.dart` jogava a mesma
  combinação duas vezes pro mesmo jogador, então o auto-equipar (com
  só 3 combinações conhecidas no total) nunca colidiu com nada
  existente.
- Fecha a sequência: Bloco 2d (UI de batalha estilo Pokémon) é o
  próximo e último, consumindo `equippedAttackIdsForPlayerA`/`B`
  pra montar os botões de ação do turno.

- [ ] **Step 5: Atualizar `TASKS.md`**

Ler `TASKS.md` e mover a entrada do Bloco 2c pra DONE, referenciando
DECISION-048. Bloco 2d continua no BACKLOG.

- [ ] **Step 6: Commit**

```bash
git add DECISIONS.md TASKS.md
git commit -m "$(cat <<'EOF'
Registra DECISION-048 e atualiza TASKS.md (ataques equipáveis)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

## Self-Review

**Cobertura do spec:**
- `AttackLoadout` (novo, separado do `DiscoveryBook`) → Task 1.
- `TrainingProgressStore` ganha 4 métodos novos → Task 2.
- Gate em `playElementIds`, auto-equipar, `lastUnlockedAttack*`,
  getters diretos por jogador, `setEquippedAttacks`,
  `fromPersistedProgress`/`startNewBattleKeepingProgress` propagando o
  loadout → Task 3.
- Catálogo pra exibição (`AttackOption`/`allAttackOptions`) → Task 4.
- Tela "Ataques Combinados" (equipar/desequipar/trocar,
  `highlightComboId`) → Task 5.
- `TrainingScreen`: botão novo na AppBar, texto inline no
  auto-equipar, abertura automática na troca, salvar
  unlocked/equipped do jogador certo → Task 6.
- Verificação manual + documentação → Task 7.
- Fora de escopo (Multiplayer, Bloco 2d) → não implementado em
  nenhuma task, registrado no BACKLOG na Task 7.

**Placeholder scan:** nenhum "TBD"/"depois"/passo sem código real —
todo Step de código tem o trecho exato; o `AttacksScreen` (Task 5) e o
`training_screen.dart` (Task 6) têm o arquivo/diff completo, não
resumos.

**Consistência de tipos:** `AttackLoadout{unlockedCombinationIds,
equippedCombinationIds}`/`isUnlocked`/`isEquipped`/`withUnlocked`/
`withEquipped` idênticos entre onde nasce (Task 1) e onde é consumido
(Task 3); `AttackOption{id,name,description,unlocked,equipped}` e
`allAttackOptions` consistentes entre Task 4 (onde nasce) e Tasks 5-6
(onde é usado); `lastUnlockedAttackId`/`lastUnlockedAttackName`/
`lastUnlockedAttackNeededEquipChoice`/`unlockedAttackIdsForPlayerA`/`B`/
`equippedAttackIdsForPlayerA`/`B`/`setEquippedAttacks({required
forPlayerA, required combinationIds})` com os mesmos nomes exatos
entre Task 3 (onde nascem) e Task 6 (onde são consumidos) — a spec
original propunha variantes `..ForCurrentPlayer`, corrigidas pra
diretas por jogador durante este plano (ver a nota de design na Task
3): confirmado que **nenhuma** referência a `..ForCurrentPlayer` de
ataques sobra em nenhuma task deste plano.
