import 'package:battle_engine/battle_engine.dart';
import 'dungeon_progress.dart';
import 'dungeon_progress_store.dart';
import 'training_match.dart';
import 'dungeon_catalog.dart';
import 'dungeon_opponent.dart';
export 'dungeon_catalog.dart';
export 'dungeon_opponent.dart';

class DungeonEncounter {
  DungeonEncounter._(this.run, this.index, this.match) {
    _intent = DungeonOpponent.plan(match, room);
  }
  final int run, index;
  final TrainingMatch match;
  DungeonRoom get room => DungeonRoom.all[index];
  late DungeonIntent _intent;
  int _plannedTurn = 0;

  DungeonIntent get intent {
    if (!match.isOver && _plannedTurn != match.cumulativeTurnsPlayedB) {
      _plannedTurn = match.cumulativeTurnsPlayedB;
      _intent = DungeonOpponent.plan(match, room);
    }
    return _intent;
  }

  DungeonIntent chooseAction() => DungeonOpponent.resolve(match, intent);
}

class DungeonCampaign {
  DungeonCampaign(this._progress, this.store);
  final DungeonProgressStore store;
  DungeonProgress _progress;
  DungeonProgress get progress => _progress;
  DungeonEncounter? _encounter;
  bool _saving = false;

  Future<void> _save(DungeonProgress next) async {
    if (_saving) throw StateError('Aguarde o salvamento.');
    _saving = true;
    try {
      await store.save(next);
      _progress = next;
    } finally {
      _saving = false;
    }
  }

  Future<void> prepare(List<String> ids) => _save(progress.prepare(ids));
  Future<void> unlock(String id) {
    if (_encounter != null) {
      throw StateError('Evolua sua árvore no acampamento.');
    }
    return _save(progress.unlock(id));
  }

  Future<void> start() async {
    if (!progress.prepared || progress.active) {
      throw StateError('Expedição indisponível.');
    }
    await _save(
      progress.copyWith(
        active: true,
        run: progress.run + 1,
        room: 0,
        hp: progress.maxHp,
      ),
    );
  }

  Future<void> abandon() async {
    if (_encounter != null) throw StateError('Saia da batalha primeiro.');
    await _save(progress.copyWith(active: false, room: 0, hp: progress.maxHp));
  }

  DungeonEncounter enter() {
    if (!progress.active || _saving || _encounter != null) {
      throw StateError('Sala indisponível.');
    }
    final room = DungeonRoom.all[progress.room];
    final enemySkills = SkillProgress(
      defaultSkillTree,
      unlockedNodeIds: room.elements.map((id) => 'unlock_$id').toList(),
    );
    return _encounter = DungeonEncounter._(
      progress.run,
      progress.room,
      TrainingMatch(
        initialProgressA: progress.skills,
        initialProgressB: enemySkills,
        initialDiscoveryBook: DiscoveryBook(
          discoveredCombinationIds: progress.attacks.toSet(),
        ),
        initialLoadoutA: AttackLoadout(
          unlockedCombinationIds: progress.attacks.toSet(),
          equippedCombinationIds: progress.equippedAttacks,
        ),
        initialLoadoutB: AttackLoadout(
          unlockedCombinationIds: room.attacks.toSet(),
          equippedCombinationIds: room.attacks,
        ),
        initialApB: ApPool(max: 5, current: room.initialAp),
        initialEquippedElementsA: progress.elements,
        initialEquippedElementsB: room.elements,
        opponentBaseHp: room.hp,
        initialPlayerHp: progress.hp,
      ),
    );
  }

  /// Leaving an unfinished room restarts it at its checkpoint; no XP is granted.
  void leave(DungeonEncounter encounter) {
    if (identical(encounter, _encounter)) _encounter = null;
  }

  Future<String> complete(DungeonEncounter encounter) async {
    if (!identical(_encounter, encounter) ||
        !progress.active ||
        encounter.run != progress.run ||
        encounter.index != progress.room ||
        !encounter.match.isOver) {
      throw StateError('Resultado já recebido ou encontro inválido.');
    }
    final match = encounter.match;
    final won = match.playerAWon;
    final cleared = won && encounter.index == DungeonRoom.all.length - 1;
    final xp = won ? encounter.room.xp : 0;
    final oldLevel = progress.level;
    final next = progress.copyWith(
      xp: progress.xp + xp,
      active: won && !cleared,
      room: won && !cleared ? progress.room + 1 : 0,
      hp: won
          ? (match.playerACurrentHp + 25).clamp(1, progress.maxHp)
          : progress.maxHp,
      clears: progress.clears + (cleared ? 1 : 0),
      // Only the human's discoveries/attacks enter the persistent profile.
      attacks: match.unlockedAttackIdsForPlayerA,
      equippedAttacks: match.equippedAttackIdsForPlayerA,
      elements: match.equippedElementIdsForPlayerA,
    );
    await _save(next);
    _encounter = null;
    final levels = next.level - oldLevel;
    return '${cleared
            ? 'Ruína concluída!'
            : won
            ? 'Sala vencida!'
            : 'Expedição encerrada.'}\n'
        '+$xp XP${levels > 0 ? ' · Nível ${next.level} · +$levels ponto(s)' : ''}\n'
        '${next.active ? 'Fogueira: recuperou até 25 HP. Próxima sala disponível.' : 'Progresso salvo. Prepare sua próxima expedição.'}';
  }
}
