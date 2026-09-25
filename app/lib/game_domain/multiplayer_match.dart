import 'effect_badge_view.dart';
import 'battle_progress.dart';
import 'multiplayer_client.dart';
import 'multiplayer_exception.dart';
import 'multiplayer_models.dart';
import 'action_preview.dart';
import 'status_catalog.dart';

/// A multiplayer match seen from one player's device. Thin wrapper around
/// [MultiplayerClient] + the last [RemoteMatch] fetched from the backend —
/// the backend is the sole authority (see ARCHITECTURE.md's Multiplayer
/// section); this class never computes damage/turn order itself, only
/// reads what the server already decided and exposes it in terms of
/// "me"/"opponent" for the UI.
///
/// No realtime push (see DECISION-016) — callers are expected to call
/// [refresh] on a timer (or after an action) to pick up the opponent's
/// moves.
class MultiplayerMatch {
  MultiplayerMatch({
    required MultiplayerClient client,
    required this.localPlayerId,
  }) : _client = client;

  final MultiplayerClient _client;
  final String localPlayerId;

  RemoteMatch? _match;
  String? _lastError;
  String? _lastTriggeredCombinationId;
  bool _submitting = false;
  int _stateGeneration = 0;
  bool _refreshing = false;
  String? connectionError;
  BattleProgress? _startingProgress;
  bool _canCaptureProgress = true;

  BattleProgress get battleProgress => BattleProgress(
    discoveries: discoveries,
    attacks: discoveries,
    skills: unlockedNodeIdsForMe,
  );

  BattleProgress? get battleGains =>
      battleProgress.gainedSince(_startingProgress);

  void _captureStartingProgress() {
    if (_canCaptureProgress &&
        _startingProgress == null &&
        !needsPreparation &&
        !isFinished) {
      _startingProgress = battleProgress;
    }
  }

  Map<String, dynamic> get progress =>
      (_match?.players[localPlayerId] as Map<String, dynamic>?) ?? const {};
  bool get needsPreparation => progress['ready'] != true;
  bool get bothReady =>
      _match?.players.length == 2 &&
      _match!.players.values.every((p) => p['ready'] == true);
  List<String> get equippedElements =>
      (progress['elements'] as List? ?? []).cast<String>();
  List<String> get equippedAttacks =>
      (progress['attacks'] as List? ?? []).cast<String>();
  List<String> get discoveries =>
      (progress['discoveries'] as List? ?? []).cast<String>();
  String? elementUnlockHint(String nodeId) {
    if (!nodeId.startsWith('unlock_') ||
        unlockedNodeIdsForMe.contains(nodeId)) {
      return null;
    }
    final required =
        (unlockedNodeIdsForMe.where((id) => id.startsWith('unlock_')).length -
            1) *
        10;
    final remaining = required - (progress['turns'] as int? ?? 0);
    return remaining > 0 ? 'Faltam $remaining turnos para desbloquear.' : null;
  }

  Future<void> configure(String kind, List<String> ids) async {
    if (_submitting) throw StateError('Aguarde a operação atual.');
    _submitting = true;
    _stateGeneration++;
    try {
      _match = await _client.configure(
        matchId!,
        localPlayerId,
        kind,
        ids,
        _match!.revision,
      );
      _captureStartingProgress();
    } finally {
      _submitting = false;
    }
  }

  RemoteMatch? get match => _match;
  bool? get channelingLeft =>
      _match?.seal == null ? null : _match!.seal!['actorId'] == localPlayerId;

  Future<int> beginSeal(List<String> ids) async {
    if (_submitting) throw StateError('Aguarde a operação atual.');
    _submitting = true;
    _stateGeneration++;
    final clock = Stopwatch()..start();
    try {
      _match = await _client.seal(matchId!, {
        'actorId': localPlayerId,
        'elementIds': ids,
        'revision': _match!.revision,
      });
      _lastError = null;
      // Conservative full RTT subtraction: no client/server clock dependency.
      return (_match!.seal!['durationMs'] as int) - clock.elapsedMilliseconds;
    } on MultiplayerException catch (e) {
      _lastError = e.message;
      rethrow;
    } finally {
      _submitting = false;
    }
  }

  Future<void> resolveSeal(List<Map<String, num>> trace) async {
    if (_submitting) throw StateError('Aguarde a operação atual.');
    final sealId = _match?.seal?['id'];
    if (sealId == null) {
      await refresh();
      throw StateError(
        'Conexão interrompida. Aguarde a sincronização do selo.',
      );
    }
    _submitting = true;
    _stateGeneration++;
    try {
      _match = await _client.seal(matchId!, {
        'actorId': localPlayerId,
        'sealId': sealId,
        'trace': trace,
      }, finish: true);
      _lastTriggeredCombinationId = _match!.lastAction?['comboId'] as String?;
      _lastError = null;
    } on MultiplayerException catch (e) {
      _lastError = e.message;
      rethrow;
    } finally {
      _submitting = false;
    }
  }

  String? get matchId => _match?.id;
  String? get lastError => _lastError;
  String? get lastTriggeredCombinationId => _lastTriggeredCombinationId;

  bool get isWaitingForOpponent => _match?.status == 'waiting_for_opponent';
  bool get isInProgress => _match?.status == 'in_progress';
  bool get isFinished => _match?.status == 'finished';

  bool get isMyTurn => _match?.state?.currentTurnId == localPlayerId;

  String? get winnerId => _match?.state?.winner;
  bool get amIWinner => winnerId != null && winnerId == localPlayerId;

  String? get _opponentId {
    final state = _match?.state;
    if (state == null) return null;
    return state.playerAId == localPlayerId ? state.playerBId : state.playerAId;
  }

  RemoteHpPool? _hpOf(String? playerId) {
    if (playerId == null) return null;
    return _match?.state?.hp[playerId];
  }

  int? get myCurrentHp => _hpOf(localPlayerId)?.current;
  int? get myMaxHp => _hpOf(localPlayerId)?.max;
  int? get opponentCurrentHp => _hpOf(_opponentId)?.current;
  int? get opponentMaxHp => _hpOf(_opponentId)?.max;

  List<String> get activeFieldEffectIds =>
      _match?.state?.activeFieldEffects.map((e) => e.id).toList() ?? const [];

  List<EffectBadgeView> _statusesOf(String? playerId) {
    if (playerId == null) return const [];
    final statuses = _match?.state?.combatantStatuses[playerId] ?? const [];
    return statuses
        .map(
          (s) =>
              EffectBadgeView(id: s.effectId, remainingTurns: s.turnsRemaining),
        )
        .toList();
  }

  List<EffectBadgeView> get myActiveStatuses => _statusesOf(localPlayerId);

  List<EffectBadgeView> get opponentActiveStatuses => _statusesOf(_opponentId);

  bool get amIFrozen => myActiveStatuses.any((status) => status.id == 'freeze');

  List<EffectBadgeView> get activeFieldEffectBadges =>
      _match?.state?.activeFieldEffects
          .map((e) => EffectBadgeView(id: e.id, remainingTurns: e.duration))
          .toList() ??
      const [];

  RemoteApPool? _apOf(String? playerId) {
    if (playerId == null) return null;
    return _match?.state?.ap[playerId];
  }

  int get myAp => _apOf(localPlayerId)?.current ?? 0;
  int get myApMax => _apOf(localPlayerId)?.max ?? 5;
  int get opponentAp => _apOf(_opponentId)?.current ?? 0;
  int get opponentApMax => _apOf(_opponentId)?.max ?? 5;

  /// Skill Tree node ids [localPlayerId] has unlocked in this match — ids
  /// only, same reasoning as elsewhere in this class (no `battle_engine`
  /// type here; the UI maps ids to display info via
  /// `skill_tree_catalog.dart`, which already has the real tree).
  List<String> get unlockedNodeIdsForMe =>
      _match?.skillProgress[localPlayerId] ?? const [];

  /// Creates a new match with [localPlayerId] as playerA. Leaves it
  /// `waiting_for_opponent` — share [matchId] with a friend so they can
  /// [join].
  Future<void> create() async {
    _lastError = null;
    _match = await _client.createMatch(localPlayerId);
    _startingProgress = null;
    _canCaptureProgress = true;
    _captureStartingProgress();
  }

  /// Joins an existing match as playerB, starting the battle.
  Future<void> join(String matchId) async {
    _lastError = null;
    _match = await _client.joinMatch(matchId, localPlayerId);
    _startingProgress = null;
    _canCaptureProgress = true;
    _captureStartingProgress();
  }

  /// Re-fetches an existing match [localPlayerId] is already part of —
  /// e.g. after closing/reloading the tab and coming back with just the
  /// shared code. Unlike [join], this never changes who's playerA/playerB
  /// server-side (it's a plain `GET`). Throws [MultiplayerException] if
  /// [localPlayerId] isn't actually `playerAId`/`playerBId` on that match —
  /// the backend's `GET /matches/:id` doesn't check this itself (see
  /// ARCHITECTURE.md's Multiplayer section), so it's enforced here instead.
  Future<void> reconnect(String matchId) async {
    _lastError = null;
    final fetched = await _client.getMatch(matchId);
    if (fetched.playerAId != localPlayerId &&
        fetched.playerBId != localPlayerId) {
      throw MultiplayerException('você não faz parte da partida "$matchId"');
    }
    _match = fetched;
    // A reconnect cannot reconstruct gains from before this session.
    _startingProgress = null;
    _canCaptureProgress = false;
    await _client.rememberSession(fetched.id, localPlayerId);
  }

  /// Re-fetches the match from the server — the only way this side finds
  /// out about the opponent joining or playing (see class doc).
  Future<void> refresh() async {
    if (_submitting || _refreshing) return;
    final generation = _stateGeneration;
    final id = matchId;
    if (id == null) return;
    try {
      _refreshing = true;
      final fetched = await _client.getMatch(id);
      if (!_submitting &&
          generation == _stateGeneration &&
          fetched.revision >= (_match?.revision ?? 0)) {
        _match = fetched;
        _captureStartingProgress();
      }
      connectionError = null;
    } catch (error) {
      connectionError = error is MultiplayerException && error.statusCode == 404
          ? 'Sala não encontrada. O servidor pode ter reiniciado; crie uma nova partida.'
          : 'Conexão interrompida. Tentando reconectar…';
      // Transient network hiccup during polling: keep the last known
      // state and let the next poll try again.
    } finally {
      _refreshing = false;
    }
  }

  /// Plays [elementIds] as [localPlayerId]'s action. Throws
  /// [MultiplayerException] if the backend rejects it (not your turn,
  /// match already over, etc.) — [lastError] carries the message for the
  /// UI to show.
  Future<void> playElementIds(
    List<String> elementIds, {
    bool defending = false,
    bool thawing = false,
  }) async {
    if (_submitting) throw StateError('Uma ação já está sendo enviada.');
    final id = matchId;
    if (id == null) {
      throw StateError('no match to play in — call create()/join() first');
    }
    try {
      _submitting = true;
      _stateGeneration++;
      _lastError = null;
      final result = await _client.submitTurn(
        id,
        actorId: localPlayerId,
        elementIds: elementIds,
        defending: defending,
        thawing: thawing,
        revision: _match!.revision,
      );
      _match = result.match;
      _lastTriggeredCombinationId = result.triggeredCombinationId;
    } on MultiplayerException catch (e) {
      _lastError = e.message;
      rethrow;
    } finally {
      _submitting = false;
    }
  }

  Future<ActionPreview> previewAction(
    List<String> ids, {
    bool defending = false,
    bool thawing = false,
  }) async {
    final snapshot = _match?.state;
    final id = matchId;
    if (snapshot == null || id == null) {
      throw StateError('Partida indisponível.');
    }
    final result = await _client.submitTurn(
      id,
      actorId: localPlayerId,
      elementIds: ids,
      defending: defending,
      thawing: thawing,
      preview: true,
      revision: _match!.revision,
    );
    final after = result.match.state!;
    final before = result.beforeState!;
    final opponent = before.playerAId == localPlayerId
        ? before.playerBId
        : before.playerAId;
    final pool = before.ap[localPlayerId];
    final regenerates =
        !thawing &&
        !(before.combatantStatuses[localPlayerId] ?? []).any(
          (s) => s.effectId == 'slow',
        );
    final available = !regenerates
        ? pool?.current ?? 0
        : ((pool?.current ?? 0) + 1).clamp(0, pool?.max ?? 5);
    return ActionPreview(
      apCost: available - after.ap[localPlayerId]!.current,
      apAfter: after.ap[localPlayerId]!.current,
      opponentHpLoss:
          before.hp[opponent]!.current - after.hp[opponent]!.current,
      selfHpLoss:
          before.hp[localPlayerId]!.current - after.hp[localPlayerId]!.current,
      effects: [
        if (thawing) 'Congelamento removido · ação perdida.',
        for (final entry in after.combatantStatuses.entries)
          for (final status in entry.value)
            '${entry.key == localPlayerId ? 'Você' : 'Adversário'}: '
                '${status.effectId == 'guard' ? 'Defesa 50%' : statusName(status.effectId)}'
                '${status.damagePerTick > 0 ? ' · ${status.damagePerTick} dano/ação' : ''}'
                '${status.turnsRemaining == null ? '' : ' · ${status.turnsRemaining} ação(ões)'}',
      ],
      regeneratesAp: regenerates,
    );
  }

  /// Unlocks [nodeId] for [localPlayerId]. Only works on [localPlayerId]'s
  /// own turn (backend-enforced — see DECISION-025); doesn't itself pass
  /// the turn, so playing an element afterwards in the same turn cycle
  /// already benefits from whatever the node granted. Throws
  /// [MultiplayerException] if the backend rejects it (not your turn,
  /// prerequisites not met, already unlocked...) — [lastError] carries
  /// the message for the UI to show.
  Future<void> unlockSkill(String nodeId) async {
    if (_submitting) throw StateError('Aguarde a operação atual.');
    final id = matchId;
    if (id == null) {
      throw StateError(
        'no match to unlock a skill in — call create()/join() first',
      );
    }
    try {
      _submitting = true;
      _stateGeneration++;
      _lastError = null;
      _match = await _client.unlockSkill(
        id,
        playerId: localPlayerId,
        nodeId: nodeId,
        revision: _match!.revision,
      );
    } on MultiplayerException catch (e) {
      _lastError = e.message;
      rethrow;
    } finally {
      _submitting = false;
    }
  }

  /// Starts a brand-new match for a rematch: there's no "reset" on the
  /// backend (a finished [Match] stays finished), so this is exactly
  /// [create] under a new id, as [localPlayerId]'s new playerA. Returns a
  /// separate [MultiplayerMatch] — this instance keeps pointing at the
  /// finished match. The new code still has to be shared with the
  /// opponent the same way the first one was (no matchmaking — ver
  /// ARCHITECTURE.md's Multiplayer section).
  Future<MultiplayerMatch> startRematch() async {
    final rematch = MultiplayerMatch(
      client: _client,
      localPlayerId: localPlayerId,
    );
    await rematch.create();
    return rematch;
  }
}
