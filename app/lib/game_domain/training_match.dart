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
        .map((targeted) => targeted.status.effect.name)
        .toList();
    if (result.triggeredCombination != null) {
      _discoveryBook = _discoveryBook.withDiscovered(
        result.triggeredCombination!,
      );
    }
    _turnsPlayed++;
  }
}
