import 'package:battle_engine/battle_engine.dart';

import 'effect_badge_view.dart';
import 'attack_catalog.dart';
import 'skill_tree_catalog.dart';
import 'action_preview.dart';

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
  late AttackLoadout _loadoutA;
  late AttackLoadout _loadoutB;
  late List<String> _elementsA;
  late List<String> _elementsB;
  late int _cumulativeTurnsA;
  late int _cumulativeTurnsB;

  String? _lastTriggeredCombinationName;
  List<String> _lastAppliedStatusNames = [];
  String? _lastUnlockedAttackId;
  String? _lastUnlockedAttackName;
  bool _lastUnlockedAttackNeededEquipChoice = false;
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
  /// elementos), default 0. [initialLoadoutA]/[initialLoadoutB] seedam
  /// os ataques já desbloqueados/equipados de cada jogador (Bloco 2c),
  /// default `AttackLoadout()` vazio.
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
    List<String>? initialEquippedElementsA,
    List<String>? initialEquippedElementsB,
  }) {
    _progressA = initialProgressA ?? SkillProgress(defaultSkillTree);
    _progressB = initialProgressB ?? SkillProgress(defaultSkillTree);
    _discoveryBook = initialDiscoveryBook ?? DiscoveryBook();
    _cumulativeTurnsA = initialTurnsPlayedA;
    _cumulativeTurnsB = initialTurnsPlayedB;
    _loadoutA = initialLoadoutA ?? AttackLoadout();
    _loadoutB = initialLoadoutB ?? AttackLoadout();
    _elementsA = _restoreElements(initialEquippedElementsA, _progressA);
    _elementsB = _restoreElements(initialEquippedElementsB, _progressB);
    _state = BattleState.start(
      playerA: _playerA,
      playerB: _playerB,
      playerAMaxHp: _baseMaxHp + _progressA.grantedMaxHpBonus,
      playerBMaxHp: _baseMaxHp + _progressB.grantedMaxHpBonus,
      ap: {_playerA: ?initialApA, _playerB: ?initialApB},
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
    required List<String> unlockedAttackIdsA,
    required List<String> equippedAttackIdsA,
    required List<String> unlockedAttackIdsB,
    required List<String> equippedAttackIdsB,
    List<String>? equippedElementIdsA,
    List<String>? equippedElementIdsB,
  }) {
    return TrainingMatch(
      initialEquippedElementsA: equippedElementIdsA,
      initialEquippedElementsB: equippedElementIdsB,
      initialProgressA: SkillProgress(
        defaultSkillTree,
        unlockedNodeIds: unlockedNodeIdsA,
      ),
      initialProgressB: SkillProgress(
        defaultSkillTree,
        unlockedNodeIds: unlockedNodeIdsB,
      ),
      initialDiscoveryBook: DiscoveryBook(
        discoveredCombinationIds: discoveredCombinationIds.toSet(),
      ),
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
      initialLoadoutA: _loadoutA,
      initialLoadoutB: _loadoutB,
      initialEquippedElementsA: _elementsA,
      initialEquippedElementsB: _elementsB,
    );
  }

  int get turnsPlayed => _turnsPlayed;

  // Older saves have no element loadout. Keep unlocked progress intact and
  // seed up to four slots; filter stale/duplicate IDs at this storage boundary.
  static List<String> _restoreElements(
    List<String>? saved,
    SkillProgress progress,
  ) {
    final unlocked = progress.grantedElementIds;
    final valid = (saved ?? unlocked)
        .where(unlocked.contains)
        .toSet()
        .take(4)
        .toList();
    return List.unmodifiable(valid.isEmpty ? unlocked.take(4) : valid);
  }

  List<String> get equippedElementIdsForPlayerA => _elementsA;
  List<String> get equippedElementIdsForPlayerB => _elementsB;
  List<String> get equippedElementIdsForCurrentPlayer =>
      _isPlayerATurn ? _elementsA : _elementsB;

  void setEquippedElements(List<String> ids) {
    if (isOver) throw StateError('A partida terminou.');
    if (ids.isEmpty || ids.length > 4 || ids.toSet().length != ids.length) {
      throw ArgumentError('Escolha de 1 a 4 elementos diferentes.');
    }
    if (ids.any((id) => !availableElementIdsForCurrentPlayer.contains(id))) {
      throw ArgumentError('Elemento bloqueado ou inexistente.');
    }
    if (_isPlayerATurn) {
      _elementsA = List.unmodifiable(ids);
    } else {
      _elementsB = List.unmodifiable(ids);
    }
  }

  int get availableApForAction =>
      TurnEngine.availableAp(_state, _currentCombatant);

  int attackApCost(int elementCount) =>
      TurnEngine.actionCost(_state, _currentCombatant, elementCount);

  bool get currentPlayerIsSilenced =>
      _state.hasStatus(_currentCombatant, StatusEffects.silence);
  String? get currentActionWarning => currentPlayerIsSilenced
      ? '${StatusEffects.silence.name}: ${StatusEffects.silence.description}'
      : _state.hasStatus(_currentCombatant, StatusEffects.slow)
      ? '${StatusEffects.slow.name}: ${StatusEffects.slow.description}'
      : _state.hasStatus(_currentCombatant, StatusEffects.shock)
      ? '${StatusEffects.shock.name}: ${StatusEffects.shock.description}'
      : null;

  List<AttackOption> get equippedAttacksForCurrentPlayer {
    final catalog = allAttackOptions(
      unlockedIds: _currentLoadout.unlockedCombinationIds.toList(),
      equippedIds: _currentLoadout.equippedCombinationIds,
    );
    return [
      for (final id in _currentLoadout.equippedCombinationIds)
        for (final attack in catalog)
          if (attack.id == id) attack,
    ];
  }

  String? attackUnavailableReason(String id) {
    if (isOver) return 'A partida terminou.';
    if (currentPlayerIsSilenced) {
      return 'Silêncio: use um elemento básico ou Defender.';
    }
    final attacks = allAttackOptions(
      unlockedIds: _currentLoadout.unlockedCombinationIds.toList(),
      equippedIds: _currentLoadout.equippedCombinationIds,
    ).where((a) => a.id == id);
    if (attacks.isEmpty) return 'Ataque inexistente.';
    final attack = attacks.first;
    if (!attack.unlocked || !attack.equipped) return 'Ataque não equipado.';
    if (attack.elementIds.any(
      (id) => !availableElementIdsForCurrentPlayer.contains(id),
    )) {
      return 'Elemento necessário bloqueado.';
    }
    final missing =
        TurnEngine.actionCost(
          _state,
          _currentCombatant,
          attack.elementIds.length,
        ) -
        availableApForAction;
    if (missing > 0) return 'Falta${missing == 1 ? '' : 'm'} $missing AP.';
    return null;
  }

  void playEquippedAttack(String id) {
    final reason = attackUnavailableReason(id);
    if (reason != null) throw StateError(reason);
    final attack = equippedAttacksForCurrentPlayer.firstWhere(
      (a) => a.id == id,
    );
    // A learned ability owns its recipe independently of the four basic slots.
    _resolveElements(attack.elementIds);
  }

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
      .map(
        (s) =>
            EffectBadgeView(id: s.effect.id, remainingTurns: s.turnsRemaining),
      )
      .toList();

  List<EffectBadgeView> get playerBActiveStatuses => _state
      .statusesOf(_playerB)
      .map(
        (s) =>
            EffectBadgeView(id: s.effect.id, remainingTurns: s.turnsRemaining),
      )
      .toList();

  List<EffectBadgeView> get activeFieldEffectBadges => _state.activeFieldEffects
      .map(
        (effect) =>
            EffectBadgeView(id: effect.id, remainingTurns: effect.duration),
      )
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

  AttackLoadout get _currentLoadout => _isPlayerATurn ? _loadoutA : _loadoutB;

  Combatant get _currentCombatant => _isPlayerATurn ? _playerA : _playerB;

  /// Skill nodes the player whose turn it currently is could unlock right
  /// now (prerequisites met, not yet unlocked).
  List<SkillNodeOption> get availableSkillNodesForCurrentPlayer =>
      _currentProgress.availableNodes.map(skillNodeOptionFrom).toList();

  /// Ids dos nós que o jogador da vez atual já desbloqueou — usado pela
  /// tela de Skill Tree visual (Bloco 7) pra saber o estado de cada nó da
  /// árvore inteira, não só os disponíveis agora.
  List<String> get unlockedNodeIdsForCurrentPlayer =>
      _currentProgress.unlockedNodeIds;

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
  List<String> get equippedAttackIdsForPlayerA =>
      _loadoutA.equippedCombinationIds;
  List<String> get equippedAttackIdsForPlayerB =>
      _loadoutB.equippedCombinationIds;

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
    final cumulativeTurns = _isPlayerATurn
        ? _cumulativeTurnsA
        : _cumulativeTurnsB;
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
      final requiredTurns =
          (_currentProgress.grantedElementIds.length - 1) * 10;
      final cumulativeTurns = _isPlayerATurn
          ? _cumulativeTurnsA
          : _cumulativeTurnsB;
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
    if (grant is ElementUnlock &&
        equippedElementIdsForCurrentPlayer.length < 4) {
      setEquippedElements([
        ...equippedElementIdsForCurrentPlayer,
        grant.elementId,
      ]);
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
  /// Throws `StateError` if the match is already over, if there isn't
  /// enough AP for the combination attempted (Bloco 2a, from
  /// `TurnEngine`), or if the combination is already unlocked for this
  /// player but not equipped (Bloco 2c).
  void playElementIds(List<String> elementIds) {
    if (isOver) throw StateError('A partida terminou.');
    for (final id in elementIds) {
      if (!availableElementIdsForCurrentPlayer.contains(id)) {
        throw ArgumentError('Elemento bloqueado ou inexistente.');
      }
      if (!equippedElementIdsForCurrentPlayer.contains(id)) {
        throw StateError('Equipe esse elemento em Trocar elementos.');
      }
    }
    _resolveElements(elementIds);
  }

  void _resolveElements(List<String> elementIds) {
    final wasPlayerATurn = _isPlayerATurn;
    final loadoutBeforeThisPlay = _currentLoadout;
    final result = _simulateElements(elementIds);
    _applyResolvedAction(result, wasPlayerATurn, loadoutBeforeThisPlay);
  }

  AbilityResult _simulateElements(List<String> elementIds) {
    if (isOver) throw StateError('A partida terminou.');
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

    return _abilityEngine.useAbility(
      _state,
      _state.currentTurn,
      build.abilityById('turn_action')!,
      combinationModifiers: build.combinationModifiers,
    );
  }

  void _applyResolvedAction(
    AbilityResult result,
    bool wasPlayerATurn,
    AttackLoadout loadoutBeforeThisPlay,
  ) {
    _state = result.state;
    _lastTriggeredCombinationName = result.triggeredCombination?.resultName;
    _lastAppliedStatusNames = result.effect.statusesToApply
        .map((targeted) => targeted.status.effect.name)
        .toList();
    _lastAppliedStatusNames.addAll(
      result.triggeredCombination?.statusesToApply
              .where(
                (t) => _state.hasStatus(
                  t.target == StatusTarget.actor
                      ? _state.opponentOf(_state.currentTurn)
                      : _state.currentTurn,
                  t.status.effect,
                ),
              )
              .map((t) => t.status.effect.name) ??
          const <String>[],
    );
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
            loadoutBeforeThisPlay.equippedCombinationIds.length >= 3;
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

  void defend() {
    final actor = _state.currentTurn;
    final result = _abilityEngine.turnEngine.playTurn(
      _state,
      TurnAction.defend(actor: actor),
    );
    _state = result.state;
    _lastTriggeredCombinationName = null;
    _lastAppliedStatusNames = isOver ? [] : ['Defesa'];
    _lastUnlockedAttackId = null;
    _lastUnlockedAttackName = null;
    _lastUnlockedAttackNeededEquipChoice = false;
    _turnsPlayed++;
    if (actor == _playerA) {
      _cumulativeTurnsA++;
    } else {
      _cumulativeTurnsB++;
    }
  }

  bool get currentPlayerIsFrozen =>
      _state.hasStatus(_state.currentTurn, StatusEffects.freeze);

  void thaw() {
    final actor = _state.currentTurn;
    final result = _abilityEngine.turnEngine.playTurn(
      _state,
      TurnAction.thaw(actor: actor),
    );
    _state = result.state;
    _lastTriggeredCombinationName = null;
    _lastAppliedStatusNames = ['Congelamento quebrado'];
    _lastUnlockedAttackId = null;
    _lastUnlockedAttackName = null;
    _lastUnlockedAttackNeededEquipChoice = false;
    _turnsPlayed++;
    if (actor == _playerA) {
      _cumulativeTurnsA++;
    } else {
      _cumulativeTurnsB++;
    }
  }

  ActionPreview previewAction(
    List<String> ids, {
    bool defending = false,
    bool thawing = false,
    String? attackId,
  }) {
    if (attackId != null) {
      final reason = attackUnavailableReason(attackId);
      if (reason != null) throw StateError(reason);
      ids = equippedAttacksForCurrentPlayer
          .firstWhere((a) => a.id == attackId)
          .elementIds;
    } else if (!defending &&
        !thawing &&
        ids.any((id) => !equippedElementIdsForCurrentPlayer.contains(id))) {
      throw StateError('Equipe esse elemento em Trocar elementos.');
    }
    final actor = _state.currentTurn;
    final opponent = _state.opponentOf(actor);
    final next = thawing
        ? _abilityEngine.turnEngine
              .playTurn(_state, TurnAction.thaw(actor: actor))
              .state
        : defending
        ? _abilityEngine.turnEngine
              .playTurn(_state, TurnAction.defend(actor: actor))
              .state
        : _simulateElements(ids).state;
    final combo = ids.length > 1
        ? defaultCombinationBook.resolve(
            ids
                .map((id) => Elements.all.firstWhere((e) => e.id == id))
                .toList(),
          )
        : null;
    return ActionPreview(
      apCost: defending || thawing
          ? 0
          : TurnEngine.actionCost(_state, actor, ids.length),
      apAfter: next.apOf(actor).current,
      opponentHpLoss:
          _state.hpOf(opponent).current - next.hpOf(opponent).current,
      selfHpLoss: _state.hpOf(actor).current - next.hpOf(actor).current,
      effects: [
        if (thawing) 'Congelamento removido · ação perdida.',
        for (final target in [actor, opponent])
          for (final status in next.statusesOf(target))
            '${target == actor ? 'Você' : 'Adversário'}: ${status.effect.name}'
                '${status.effect == StatusEffects.guard ? ' · próximo golpe −50%' : ''}'
                '${status.damagePerTick > 0 ? ' · ${status.damagePerTick} dano/ação' : ''}'
                '${status.turnsRemaining == null ? '' : ' · ${status.turnsRemaining} ação(ões)'}',
        if (!defending && !thawing && ids.length > 1 && combo == null)
          'Combinação desconhecida: sem dano direto.',
      ],
      regeneratesAp: !thawing && !_state.hasStatus(actor, StatusEffects.slow),
    );
  }
}
