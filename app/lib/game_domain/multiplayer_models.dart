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
    return RemoteHpPool(max: json['max'] as int, current: json['current'] as int);
  }
}

class RemoteBattleState {
  final String playerAId;
  final String playerBId;
  final String currentTurnId;
  final List<RemoteFieldEffect> activeFieldEffects;
  final Map<String, RemoteHpPool> hp;
  final String? winner;

  const RemoteBattleState({
    required this.playerAId,
    required this.playerBId,
    required this.currentTurnId,
    required this.activeFieldEffects,
    required this.hp,
    this.winner,
  });

  factory RemoteBattleState.fromJson(Map<String, dynamic> json) {
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
      winner: json['winner'] as String?,
    );
  }
}

class RemoteMatch {
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

  const SubmitTurnResult({required this.match, this.triggeredCombinationId});
}
