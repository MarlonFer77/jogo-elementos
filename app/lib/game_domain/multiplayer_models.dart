/// Plain data mirrors of the JSON shapes served by
/// backend/src/battle-rules and backend/src/matches — deliberately not
/// `battle_engine` types (that engine doesn't run here at all; the backend
/// is the sole authority for a multiplayer match's rules, per
/// ARCHITECTURE.md). Field names match the wire format exactly, so parsing
/// is direct.
library;

class RemoteFieldEffect {
  final String id;
  final int area;
  final int? duration;
  final int damage;

  const RemoteFieldEffect({
    required this.id,
    required this.area,
    this.duration,
    required this.damage,
  });

  factory RemoteFieldEffect.fromJson(Map<String, dynamic> json) {
    return RemoteFieldEffect(
      id: json['id'] as String,
      area: json['area'] as int,
      duration: json['duration'] as int?,
      damage: json['damage'] as int? ?? 0,
    );
  }
}

class RemoteHpPool {
  final int max;
  final int current;

  const RemoteHpPool({required this.max, required this.current});

  factory RemoteHpPool.fromJson(Map<String, dynamic> json) {
    return RemoteHpPool(
      max: json['max'] as int,
      current: json['current'] as int,
    );
  }
}

class RemoteActiveStatus {
  final String effectId;
  final int? turnsRemaining;
  final int damagePerTick;

  const RemoteActiveStatus({
    required this.effectId,
    this.turnsRemaining,
    this.damagePerTick = 0,
  });

  factory RemoteActiveStatus.fromJson(Map<String, dynamic> json) {
    return RemoteActiveStatus(
      effectId: json['effectId'] as String,
      turnsRemaining: json['turnsRemaining'] as int?,
      damagePerTick: json['damagePerTick'] as int? ?? 0,
    );
  }
}

class RemoteApPool {
  final int max;
  final int current;

  const RemoteApPool({required this.max, required this.current});

  factory RemoteApPool.fromJson(Map<String, dynamic> json) {
    return RemoteApPool(
      max: json['max'] as int,
      current: json['current'] as int,
    );
  }
}

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
    final combatantStatusesJson =
        json['combatantStatuses'] as Map<String, dynamic>?;
    final apJson = json['ap'] as Map<String, dynamic>?;
    return RemoteBattleState(
      playerAId: json['playerAId'] as String,
      playerBId: json['playerBId'] as String,
      currentTurnId: json['currentTurnId'] as String,
      activeFieldEffects: (json['activeFieldEffects'] as List)
          .map((e) => RemoteFieldEffect.fromJson(e as Map<String, dynamic>))
          .toList(),
      hp: (json['hp'] as Map<String, dynamic>).map(
        (id, pool) =>
            MapEntry(id, RemoteHpPool.fromJson(pool as Map<String, dynamic>)),
      ),
      combatantStatuses: combatantStatusesJson == null
          ? const {}
          : combatantStatusesJson.map(
              (id, statuses) => MapEntry(
                id,
                (statuses as List)
                    .map(
                      (s) => RemoteActiveStatus.fromJson(
                        s as Map<String, dynamic>,
                      ),
                    )
                    .toList(),
              ),
            ),
      ap: apJson == null
          ? const {}
          : apJson.map(
              (id, pool) => MapEntry(
                id,
                RemoteApPool.fromJson(pool as Map<String, dynamic>),
              ),
            ),
      winner: json['winner'] as String?,
    );
  }
}

class RemoteMatch {
  final Map<String, dynamic>? seal;
  final int revision;
  final Map<String, dynamic> players;
  final Map<String, dynamic>? lastAction;
  final String id;
  final String playerAId;
  final String? playerBId;
  final String status;
  final RemoteBattleState? state;

  /// Unlocked Skill Tree node ids per player id — mirrors
  /// `Match.skillProgress` in the backend. Empty for a player id not
  /// present in the map (e.g. before `join`).
  final Map<String, List<String>> skillProgress;

  const RemoteMatch({
    this.seal,
    this.revision = 0,
    this.players = const {},
    this.lastAction,
    required this.id,
    required this.playerAId,
    this.playerBId,
    required this.status,
    this.state,
    this.skillProgress = const {},
  });

  factory RemoteMatch.fromJson(Map<String, dynamic> json) {
    final stateJson = json['state'] as Map<String, dynamic>?;
    final skillProgressJson = json['skillProgress'] as Map<String, dynamic>?;
    return RemoteMatch(
      seal: json['seal'] as Map<String, dynamic>?,
      revision: json['revision'] as int? ?? 0,
      players: json['players'] as Map<String, dynamic>? ?? const {},
      lastAction: json['lastAction'] as Map<String, dynamic>?,
      id: json['id'] as String,
      playerAId: json['playerAId'] as String,
      playerBId: json['playerBId'] as String?,
      status: json['status'] as String,
      state: stateJson == null ? null : RemoteBattleState.fromJson(stateJson),
      skillProgress: skillProgressJson == null
          ? const {}
          : skillProgressJson.map(
              (id, nodeIds) => MapEntry(id, (nodeIds as List).cast<String>()),
            ),
    );
  }
}

class SubmitTurnResult {
  final RemoteMatch match;
  final String? triggeredCombinationId;
  final RemoteBattleState? beforeState;

  const SubmitTurnResult({
    required this.match,
    this.triggeredCombinationId,
    this.beforeState,
  });
}
