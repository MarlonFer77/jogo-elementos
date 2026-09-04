import 'multiplayer_client.dart';
import 'multiplayer_exception.dart';
import 'multiplayer_models.dart';

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
  MultiplayerMatch({required MultiplayerClient client, required this.localPlayerId})
      : _client = client;

  final MultiplayerClient _client;
  final String localPlayerId;

  RemoteMatch? _match;
  String? _lastError;
  String? _lastTriggeredCombinationId;

  RemoteMatch? get match => _match;
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
  }

  /// Joins an existing match as playerB, starting the battle.
  Future<void> join(String matchId) async {
    _lastError = null;
    _match = await _client.joinMatch(matchId, localPlayerId);
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
    if (fetched.playerAId != localPlayerId && fetched.playerBId != localPlayerId) {
      throw MultiplayerException(
        'você não faz parte da partida "$matchId"',
      );
    }
    _match = fetched;
  }

  /// Re-fetches the match from the server — the only way this side finds
  /// out about the opponent joining or playing (see class doc).
  Future<void> refresh() async {
    final id = matchId;
    if (id == null) return;
    try {
      _match = await _client.getMatch(id);
    } on MultiplayerException {
      // Transient network hiccup during polling: keep the last known
      // state and let the next poll try again.
    }
  }

  /// Plays [elementIds] as [localPlayerId]'s action. Throws
  /// [MultiplayerException] if the backend rejects it (not your turn,
  /// match already over, etc.) — [lastError] carries the message for the
  /// UI to show.
  Future<void> playElementIds(List<String> elementIds) async {
    final id = matchId;
    if (id == null) {
      throw StateError('no match to play in — call create()/join() first');
    }
    try {
      _lastError = null;
      final result = await _client.submitTurn(
        id,
        actorId: localPlayerId,
        elementIds: elementIds,
      );
      _match = result.match;
      _lastTriggeredCombinationId = result.triggeredCombinationId;
    } on MultiplayerException catch (e) {
      _lastError = e.message;
      rethrow;
    }
  }

  /// Unlocks [nodeId] for [localPlayerId]. Only works on [localPlayerId]'s
  /// own turn (backend-enforced — see DECISION-025); doesn't itself pass
  /// the turn, so playing an element afterwards in the same turn cycle
  /// already benefits from whatever the node granted. Throws
  /// [MultiplayerException] if the backend rejects it (not your turn,
  /// prerequisites not met, already unlocked...) — [lastError] carries
  /// the message for the UI to show.
  Future<void> unlockSkill(String nodeId) async {
    final id = matchId;
    if (id == null) {
      throw StateError('no match to unlock a skill in — call create()/join() first');
    }
    try {
      _lastError = null;
      _match = await _client.unlockSkill(id, playerId: localPlayerId, nodeId: nodeId);
    } on MultiplayerException catch (e) {
      _lastError = e.message;
      rethrow;
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
    final rematch = MultiplayerMatch(client: _client, localPlayerId: localPlayerId);
    await rematch.create();
    return rematch;
  }
}
