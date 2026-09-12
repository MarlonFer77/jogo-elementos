# Progressão persistente do Modo Treino (Bloco 10) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fazer Skill Tree (por Jogador A/Jogador B) e Livro de Descobertas (compartilhado) do Modo Treino sobreviverem a "Nova partida" e a fechar/reabrir o app.

**Architecture:** `TrainingProgressStore` (novo, `game_domain`) persiste ids crus via `shared_preferences`; `TrainingMatch` ganha um construtor que aceita progresso inicial, mais um factory (`fromPersistedProgress`) e um método (`startNewBattleKeepingProgress`) que mantêm a UI livre de qualquer tipo do `battle_engine`; `TrainingScreen` carrega o progresso ao abrir (assíncrono, com loading) e salva depois de cada mudança.

**Tech Stack:** Flutter/Dart, `shared_preferences` (novo pacote), `flutter_test`.

**Spec:** [docs/superpowers/specs/2026-09-12-training-progression-design.md](../specs/2026-09-12-training-progression-design.md)

## Global Constraints

- Só o Modo Treino — Multiplayer é um bloco separado (11), depende da credencial do Firebase.
- Livro de Descobertas é **compartilhado** (uma lista só), não por slot — mesmo comportamento de hoje dentro de uma partida, só passa a persistir.
- `TrainingMatch()` sem argumentos continua se comportando exatamente como hoje — nenhum teste existente deveria quebrar.
- A UI (`training_screen.dart`) nunca importa nem nomeia um tipo do `battle_engine` (`SkillProgress`/`DiscoveryBook`) — isso fica só dentro de `training_match.dart` (DECISION-011/017). É por isso que `TrainingMatch` ganha `fromPersistedProgress`/`startNewBattleKeepingProgress` em vez da tela montar `SkillProgress`/`DiscoveryBook` diretamente (ajuste em relação ao esboço de código do spec, descoberto ao revisar o código real antes de escrever este plano).
- HP inicial de uma partida seedada com progresso já precisa somar `grantedMaxHpBonus` do progresso inicial (`_baseMaxHp + progress.grantedMaxHpBonus`), não só quando desbloqueado ao vivo.
- **Lição de teste (padrão desta sessão):** nunca chamar `pumpAndSettle()` numa árvore de widget com `AnimationController` repetindo — não se aplica a `TrainingScreen` diretamente, mas por precaução seguimos o mesmo padrão de `pump()` com duração fixa já usado em todo `training_screen_test.dart`.
- `shared_preferences` em teste usa `SharedPreferences.setMockInitialValues(...)` (utilitário oficial do próprio pacote) — não precisa de abstração/interface nova.
- `flutter run -d web-server` nunca recompila sozinho ao recarregar — sempre reiniciar com `preview_stop` + `preview_start` completo antes de verificar manualmente.

---

## Arquivos afetados

**Novos:**
- `app/lib/game_domain/training_progress_store.dart` — `TrainingProgressStore`.
- `app/test/game_domain/training_progress_store_test.dart`.

**Modificados:**
- `app/pubspec.yaml` — dependência `shared_preferences`.
- `app/lib/game_domain/training_match.dart` / `app/test/game_domain/training_match_test.dart` — construtor com progresso inicial, `fromPersistedProgress`, `startNewBattleKeepingProgress`, 3 getters novos.
- `app/lib/ui/training_screen.dart` / `app/test/training_screen_test.dart` — carregamento/salvamento, loading, "Nova partida" preserva progresso.
- `DECISIONS.md` — nova entrada DECISION-045.
- `TASKS.md` — marca o bloco como DONE.

---

### Task 1: `TrainingProgressStore`

**Files:**
- Modify: `app/pubspec.yaml`
- Create: `app/lib/game_domain/training_progress_store.dart`
- Test: `app/test/game_domain/training_progress_store_test.dart`

**Interfaces:**
- Produces: `class TrainingProgressStore { Future<List<String>> loadUnlockedNodeIds(String slot); Future<void> saveUnlockedNodeIds(String slot, List<String> unlockedNodeIds); Future<List<String>> loadDiscoveredCombinationIds(); Future<void> saveDiscoveredCombinationIds(List<String> discoveredCombinationIds); }`. `slot` é `'a'` ou `'b'`.

- [ ] **Step 1: Adicionar a dependência `shared_preferences`**

Em `app/pubspec.yaml`, na seção `dependencies:`, logo depois da linha `ota_update: ^7.1.0`:

```yaml
  ota_update: ^7.1.0
  shared_preferences: ^2.3.3
```

- [ ] **Step 2: Instalar a dependência**

Run: `cd app && flutter pub get`
Expected: conclui sem erro, `shared_preferences` aparece em `app/pubspec.lock`.

- [ ] **Step 3: Escrever os testes falhos**

Criar `app/test/game_domain/training_progress_store_test.dart`:

```dart
import 'package:app/game_domain/training_progress_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('unlocked node ids', () {
    test('an empty slot returns an empty list', () async {
      final store = TrainingProgressStore();
      expect(await store.loadUnlockedNodeIds('a'), isEmpty);
    });

    test('saves and reloads a slot', () async {
      final store = TrainingProgressStore();
      await store.saveUnlockedNodeIds('a', ['ember_mastery', 'wildfire_path']);

      expect(
        await store.loadUnlockedNodeIds('a'),
        ['ember_mastery', 'wildfire_path'],
      );
    });

    test('two slots are independent', () async {
      final store = TrainingProgressStore();
      await store.saveUnlockedNodeIds('a', ['ember_mastery']);
      await store.saveUnlockedNodeIds('b', ['vitality_training']);

      expect(await store.loadUnlockedNodeIds('a'), ['ember_mastery']);
      expect(await store.loadUnlockedNodeIds('b'), ['vitality_training']);
    });
  });

  group('discovered combination ids', () {
    test('starts empty', () async {
      final store = TrainingProgressStore();
      expect(await store.loadDiscoveredCombinationIds(), isEmpty);
    });

    test('saves and reloads', () async {
      final store = TrainingProgressStore();
      await store.saveDiscoveredCombinationIds(['ignited_storm', 'lava']);

      expect(
        await store.loadDiscoveredCombinationIds(),
        ['ignited_storm', 'lava'],
      );
    });
  });
}
```

- [ ] **Step 4: Rodar os testes e confirmar que falham**

Run: `cd app && flutter test test/game_domain/training_progress_store_test.dart`
Expected: FAIL — `training_progress_store.dart` ainda não existe.

- [ ] **Step 5: Implementar `TrainingProgressStore`**

Criar `app/lib/game_domain/training_progress_store.dart`:

```dart
import 'package:shared_preferences/shared_preferences.dart';

/// Persiste o progresso do Modo Treino (Skill Tree por slot `'a'`/`'b'`,
/// Livro de Descobertas compartilhado) entre partidas e entre execuções
/// do app — `shared_preferences`, local ao aparelho, sem rede, sem
/// custo (Bloco 10).
class TrainingProgressStore {
  static const _unlockedKeyPrefix = 'training_unlocked_';
  static const _discoveredKey = 'training_discovered';

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
}
```

- [ ] **Step 6: Rodar os testes e confirmar que passam**

Run: `cd app && flutter test test/game_domain/training_progress_store_test.dart`
Expected: PASS (5 testes).

- [ ] **Step 7: Commit**

```bash
git add app/pubspec.yaml app/pubspec.lock app/lib/game_domain/training_progress_store.dart app/test/game_domain/training_progress_store_test.dart
git commit -m "$(cat <<'EOF'
Adiciona TrainingProgressStore (Bloco 10, progressão do Treino)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: `TrainingMatch` aceita e preserva progresso

**Files:**
- Modify: `app/lib/game_domain/training_match.dart`
- Test: `app/test/game_domain/training_match_test.dart`

**Interfaces:**
- Produces: `TrainingMatch({SkillProgress? initialProgressA, SkillProgress? initialProgressB, DiscoveryBook? initialDiscoveryBook})`; `factory TrainingMatch.fromPersistedProgress({required List<String> unlockedNodeIdsA, required List<String> unlockedNodeIdsB, required List<String> discoveredCombinationIds})`; `TrainingMatch startNewBattleKeepingProgress()`; `List<String> get unlockedNodeIdsForPlayerA`; `List<String> get unlockedNodeIdsForPlayerB`; `List<String> get discoveredCombinationIds`.

- [ ] **Step 1: Escrever os testes falhos**

Em `app/test/game_domain/training_match_test.dart`, adicionar os testes novos ao final do `main()` (antes do `}` de fechamento), depois do teste `'playerAActiveStatuses/playerBActiveStatuses resolve id and remainingTurns from an applied mutation status'`:

```dart
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
      initialProgressA: SkillProgress(defaultSkillTree, unlockedNodeIds: ['ember_mastery']),
    );

    match.playElementIds(['fire']);

    expect(match.lastAppliedStatusNames, contains('Queimadura'));
  });

  test('unlockedNodeIdsForPlayerA/B and discoveredCombinationIds reflect '
      'real state', () {
    final match = TrainingMatch();
    match.unlockSkillForCurrentPlayer('ember_mastery'); // Jogador A
    match.playElementIds(['fire', 'wind']); // Jogador A, Tempestade Ígnea

    expect(match.unlockedNodeIdsForPlayerA, ['ember_mastery']);
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
      );

      expect(match.unlockedNodeIdsForPlayerA, ['ember_mastery']);
      expect(match.unlockedNodeIdsForPlayerB, ['vitality_training']);
      expect(match.discoveredCombinationIds, ['ignited_storm']);
      expect(match.playerBMaxHp, equals(120)); // Vitalidade já aplicada
    });
  });

  group('startNewBattleKeepingProgress', () {
    test('resets HP/turn/campo but keeps Skill Tree and Discovery Book', () {
      final match = TrainingMatch();
      match.unlockSkillForCurrentPlayer('vitality_training'); // Jogador A
      match.playElementIds(['fire', 'wind']); // Jogador A, descobre Tempestade Ígnea

      final rematch = match.startNewBattleKeepingProgress();

      expect(rematch.playerAMaxHp, equals(120)); // Vitalidade mantida
      expect(rematch.playerACurrentHp, equals(120)); // batalha nova, HP cheio
      expect(rematch.currentTurnName, equals('Jogador A')); // turno resetado
      expect(rematch.activeFieldEffectNames, isEmpty); // campo resetado
      expect(rematch.discoveredCombinationIds, ['ignited_storm']); // mantido
    });
  });
```

- [ ] **Step 2: Rodar os testes e confirmar que os novos falham**

Run: `cd app && flutter test test/game_domain/training_match_test.dart`
Expected: os testes antigos PASS; os novos FAIL — `initialProgressA`, `fromPersistedProgress`, `startNewBattleKeepingProgress`, `unlockedNodeIdsForPlayerA`/`B`, `discoveredCombinationIds` não existem ainda.

- [ ] **Step 3: Implementar o construtor com progresso inicial**

Em `app/lib/game_domain/training_match.dart`, substituir os campos e construir um construtor de verdade — trocar:

```dart
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
  int _turnsPlayed = 0;
```

por:

```dart
  final AbilityEngine _abilityEngine = AbilityEngine(
    TurnEngine(defaultCombinationBook),
  );

  late BattleState _state;
  late DiscoveryBook _discoveryBook;
  late SkillProgress _progressA;
  late SkillProgress _progressB;

  String? _lastTriggeredCombinationName;
  List<String> _lastAppliedStatusNames = [];
  int _turnsPlayed = 0;

  /// [initialProgressA]/[initialProgressB]/[initialDiscoveryBook] seedam
  /// uma partida já com progresso de uma partida anterior (Bloco 10 —
  /// persistência local do Modo Treino) — default vazio, mesmo
  /// comportamento de sempre quando não passados. O HP inicial já soma
  /// o bônus de qualquer `MaxHpBonus` que o progresso inicial conceda
  /// (ex: Treino de Vitalidade), não só quando desbloqueado ao vivo
  /// durante a partida.
  TrainingMatch({
    SkillProgress? initialProgressA,
    SkillProgress? initialProgressB,
    DiscoveryBook? initialDiscoveryBook,
  }) {
    _progressA = initialProgressA ?? SkillProgress(defaultSkillTree);
    _progressB = initialProgressB ?? SkillProgress(defaultSkillTree);
    _discoveryBook = initialDiscoveryBook ?? DiscoveryBook();
    _state = BattleState.start(
      playerA: _playerA,
      playerB: _playerB,
      playerAMaxHp: _baseMaxHp + _progressA.grantedMaxHpBonus,
      playerBMaxHp: _baseMaxHp + _progressB.grantedMaxHpBonus,
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
  }) {
    return TrainingMatch(
      initialProgressA: SkillProgress(defaultSkillTree, unlockedNodeIds: unlockedNodeIdsA),
      initialProgressB: SkillProgress(defaultSkillTree, unlockedNodeIds: unlockedNodeIdsB),
      initialDiscoveryBook: DiscoveryBook(discoveredCombinationIds: discoveredCombinationIds.toSet()),
    );
  }

  /// Começa uma batalha nova preservando Skill Tree/Descobertas desta
  /// partida — usado por "Nova partida" (Bloco 10): reseta HP/turno/
  /// campo, mas não a progressão.
  TrainingMatch startNewBattleKeepingProgress() {
    return TrainingMatch(
      initialProgressA: _progressA,
      initialProgressB: _progressB,
      initialDiscoveryBook: _discoveryBook,
    );
  }
```

- [ ] **Step 4: Adicionar os 3 getters novos**

No mesmo arquivo, trocar:

```dart
  List<EffectBadgeView> get activeFieldEffectBadges => _state.activeFieldEffects
      .map((effect) => EffectBadgeView(id: effect.id, remainingTurns: effect.duration))
      .toList();

  int get playerAMaxHp => _state.hpOf(_playerA).max;
```

por:

```dart
  List<EffectBadgeView> get activeFieldEffectBadges => _state.activeFieldEffects
      .map((effect) => EffectBadgeView(id: effect.id, remainingTurns: effect.duration))
      .toList();

  List<String> get unlockedNodeIdsForPlayerA => _progressA.unlockedNodeIds;

  List<String> get unlockedNodeIdsForPlayerB => _progressB.unlockedNodeIds;

  List<String> get discoveredCombinationIds =>
      _discoveryBook.discoveredCombinationIds.toList();

  int get playerAMaxHp => _state.hpOf(_playerA).max;
```

- [ ] **Step 5: Rodar os testes e confirmar que passam**

Run: `cd app && flutter test test/game_domain/training_match_test.dart`
Expected: PASS (todos os testes do arquivo, incluindo os novos).

- [ ] **Step 6: Commit**

```bash
git add app/lib/game_domain/training_match.dart app/test/game_domain/training_match_test.dart
git commit -m "$(cat <<'EOF'
TrainingMatch aceita e preserva progresso persistido (Bloco 10)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: `TrainingScreen` carrega e salva o progresso

**Files:**
- Modify: `app/lib/ui/training_screen.dart`
- Test: `app/test/training_screen_test.dart`

**Interfaces:**
- Consumes: `TrainingProgressStore` (Task 1); `TrainingMatch.fromPersistedProgress`/`startNewBattleKeepingProgress`/`unlockedNodeIdsForPlayerA`/`unlockedNodeIdsForPlayerB`/`discoveredCombinationIds` (Task 2).

- [ ] **Step 1: Escrever o teste falho do carregamento assíncrono**

Em `app/test/training_screen_test.dart`, adicionar o import:

```dart
import 'package:app/game_domain/training_match.dart';
import 'package:app/game_presentation/pixel_menu_button.dart';
import 'package:app/main.dart';
import 'package:app/ui/training_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
```

Adicionar `setUp` logo no início do `main()` (antes do primeiro `testWidgets`) — necessário porque, a partir desta task, abrir `TrainingScreen()` sem `initialMatch` (é o que "MODO TREINO" na Home faz) dispara uma leitura real de `shared_preferences`, e os testes existentes que passam por esse caminho (via `GameApp`) precisam de um mock inicializado, mesmo vazio:

```dart
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
```

E um teste novo ao final do `main()` (antes do `}` de fechamento):

```dart
  testWidgets(
    'loads persisted Skill Tree progress before showing the play form',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'training_unlocked_a': ['ember_mastery'],
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
}
```

- [ ] **Step 2: Rodar os testes e confirmar que o novo falha**

Run: `cd app && flutter test test/training_screen_test.dart`
Expected: os testes antigos continuam PASS (ainda não usam o loading); o novo teste FAIL — hoje `TrainingScreen()` sem `initialMatch` monta `TrainingMatch()` vazio na hora, síncrono, sem ler nada persistido, então "Caminho do Incêndio" continua bloqueado.

- [ ] **Step 3: Implementar o carregamento, o salvamento e a preservação de progresso**

Em `app/lib/ui/training_screen.dart`, adicionar os imports:

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
import 'skill_tree_screen.dart';
```

Trocar o estado inicial e adicionar o carregamento — trocar:

```dart
class _TrainingScreenState extends State<TrainingScreen> {
  late TrainingMatch _match = widget._initialMatch ?? TrainingMatch();
  final Set<String> _selectedIds = {};
  String? _error;
  AttackEvent? _pendingAttack;
```

por:

```dart
class _TrainingScreenState extends State<TrainingScreen> {
  final TrainingProgressStore _progressStore = TrainingProgressStore();
  late TrainingMatch _match;
  bool _loading = true;
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

  Future<void> _loadPersistedMatch() async {
    final unlockedA = await _progressStore.loadUnlockedNodeIds('a');
    final unlockedB = await _progressStore.loadUnlockedNodeIds('b');
    final discovered = await _progressStore.loadDiscoveredCombinationIds();
    if (!mounted) return;
    setState(() {
      _match = TrainingMatch.fromPersistedProgress(
        unlockedNodeIdsA: unlockedA,
        unlockedNodeIdsB: unlockedB,
        discoveredCombinationIds: discovered,
      );
      _loading = false;
    });
  }
```

Salvar Skill Tree depois de um desbloqueio com sucesso — trocar:

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

por:

```dart
  Future<void> _openSkillTree() async {
    await Navigator.of(context).push(pixelSlideRoute((_) => SkillTreeScreen(
      title: 'Habilidades de ${_match.currentTurnName}',
      unlockedNodeIds: _match.unlockedNodeIdsForCurrentPlayer,
      canUnlockNow: true,
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
```

Salvar o Livro de Descobertas quando uma combinação nova aparecer — trocar:

```dart
  void _playTurn() {
    setState(() {
      _error = null;
      final playedElementIds = _selectedIds.toList();
      final wasPlayerATurn = _match.isPlayerATurn;
      final hpABefore = _match.playerACurrentHp;
      final hpBBefore = _match.playerBCurrentHp;
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
        if (_match.isOver) {
          sfxPlayer.play(SfxId.victory);
        }
      } on ArgumentError {
        _error = 'Jogada inválida.';
      }
    });
  }
```

"Nova partida" preserva progresso — trocar:

```dart
  void _startNewMatch() {
    setState(() {
      _match = TrainingMatch();
      _selectedIds.clear();
      _error = null;
    });
  }
```

por:

```dart
  void _startNewMatch() {
    setState(() {
      _match = _match.startNewBattleKeepingProgress();
      _selectedIds.clear();
      _error = null;
    });
  }
```

Mostrar um indicador de carregamento enquanto `_loading` — trocar o início do `build`:

```dart
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: CustomPaint(painter: ArenaBackdropPainter())),
        Scaffold(
```

por:

```dart
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Stack(
      children: [
        Positioned.fill(child: CustomPaint(painter: ArenaBackdropPainter())),
        Scaffold(
```

- [ ] **Step 4: Rodar os testes e confirmar que passam**

Run: `cd app && flutter test test/training_screen_test.dart`
Expected: PASS (todos os testes do arquivo, incluindo o novo).

- [ ] **Step 5: Rodar `flutter analyze` no app**

Run: `cd app && flutter analyze`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add app/lib/ui/training_screen.dart app/test/training_screen_test.dart
git commit -m "$(cat <<'EOF'
TrainingScreen carrega e salva a progressão persistente (Bloco 10)

"Nova partida" volta a preservar Skill Tree/Descobertas em vez de
resetar — só a batalha (HP/turno/campo) recomeça.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Suíte completa, verificação manual e documentação

**Files:**
- Modify: `DECISIONS.md`
- Modify: `TASKS.md`

**Interfaces:**
- Nenhuma — task de fechamento, sem código novo.

- [ ] **Step 1: Rodar a suíte completa do app**

Run: `cd app && flutter test`
Expected: todos os testes PASS (os existentes + os novos das Tasks 1-3).

- [ ] **Step 2: Rodar `flutter analyze` uma última vez no app**

Run: `cd app && flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: Verificar manualmente via `flutter run -d web-server`**

Reiniciar o preview com `preview_stop` + `preview_start` (nunca só recarregar — e desta vez é ainda mais importante, já que `shared_preferences` na Web usa `localStorage` do navegador, então um simples reload de página já bastaria pra persistir, mas o restart do processo Flutter continua sendo necessário pra pegar o código novo). Confirmar:
- Desbloquear "Maestria da Brasa" pro Jogador A, dar F5/recarregar a aba, abrir o Modo Treino de novo — o nó continua desbloqueado (o ícone de Habilidades mostra "Caminho do Incêndio" disponível, não travado).
- Jogar Fogo+Vento pra descobrir Tempestade Ígnea, recarregar — "Descobertas: 1/3" continua depois de recarregar.
- Clicar "Nova partida" depois do fim de uma partida — HP volta a 100 (+ bônus de Vitalidade se desbloqueado), mas a Skill Tree continua desbloqueada.
- Nenhum erro no console do navegador.

- [ ] **Step 4: Registrar DECISION-045 em `DECISIONS.md`**

Ler `DECISIONS.md`, localizar a última entrada (`DECISION-044`), e adicionar uma nova entrada `DECISION-045` logo depois, cobrindo:
- Bloco 10 (progressão, Modo Treino): Skill Tree por Jogador A/Jogador B e Livro de Descobertas compartilhado passam a persistir via `shared_preferences`, local ao aparelho — sobrevivem a "Nova partida" e a fechar/reabrir o app.
- `TrainingMatch` ganhou `fromPersistedProgress`/`startNewBattleKeepingProgress` em vez da UI montar `SkillProgress`/`DiscoveryBook` diretamente — mantém a regra de que a UI nunca nomeia um tipo do `battle_engine` (DECISION-011/017), ajuste descoberto revisando o código real antes de escrever o plano.
- Escopo explícito: só Modo Treino. Multiplayer é o Bloco 11 (Skill Tree persistente + Livro de Descobertas novo no backend via Firestore), que depende da credencial de serviço do projeto Firebase real criado nesta sessão (`elements-1173d`).

- [ ] **Step 5: Atualizar `TASKS.md`**

Ler `TASKS.md` e mover a entrada do Bloco 10 (progressão — Treino) pra DONE, referenciando DECISION-045, e registrar no BACKLOG a existência do Bloco 11 (Multiplayer) como próximo passo dependente da credencial do Firebase.

- [ ] **Step 6: Commit**

```bash
git add DECISIONS.md TASKS.md
git commit -m "$(cat <<'EOF'
Registra DECISION-045 e atualiza TASKS.md (progressão do Treino)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

## Self-Review

**Cobertura do spec:**
- `TrainingProgressStore` (shared_preferences, sem JSON) → Task 1.
- `TrainingMatch` com progresso inicial + HP corrigido (`grantedMaxHpBonus`) → Task 2.
- `fromPersistedProgress`/`startNewBattleKeepingProgress` (refinamento sobre o esboço do spec, pra respeitar DECISION-011/017 — a tela nunca monta `SkillProgress`/`DiscoveryBook` diretamente) → Task 2.
- Carregamento assíncrono com loading, salvamento após desbloqueio/descoberta, "Nova partida" preservando progresso → Task 3.
- "Nenhum teste existente deveria quebrar" → confirmado a cada task e na suíte completa (Task 4); `TrainingMatch()`/`TrainingScreen(initialMatch: ...)` continuam com o mesmo comportamento síncrono de sempre.
- Verificação manual via web-server (persistência real via `localStorage`) → Task 4.
- Fora de escopo (Multiplayer/Bloco 11, Descobertas por slot, sincronização entre aparelhos) → não implementado em nenhuma task, registrado no BACKLOG na Task 4.

**Placeholder scan:** nenhum "TBD"/"depois"/passo sem código real — todo Step de código tem o trecho exato a escrever (before/after) ou o arquivo novo por inteiro.

**Consistência de tipos:** `TrainingProgressStore` com as 4 assinaturas idênticas entre Task 1 (onde nasce) e Task 3 (onde é consumida); `TrainingMatch.fromPersistedProgress`/`startNewBattleKeepingProgress`/`unlockedNodeIdsForPlayerA`/`unlockedNodeIdsForPlayerB`/`discoveredCombinationIds` com as mesmas assinaturas entre Task 2 e Task 3.
