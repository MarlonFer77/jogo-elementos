import 'package:app/game_domain/dungeon_campaign.dart';
import 'package:app/game_domain/dungeon_progress.dart';
import 'package:app/game_domain/dungeon_progress_store.dart';
import 'package:app/game_domain/training_match.dart';
import 'package:battle_engine/battle_engine.dart';
import 'package:flutter_test/flutter_test.dart';

TrainingMatch encounter(DungeonRoom room, {int turn = 0, int? ap}) =>
    TrainingMatch(
      initialProgressA: SkillProgress(
        defaultSkillTree,
        unlockedNodeIds: Elements.all.map((e) => 'unlock_${e.id}').toList(),
      ),
      initialProgressB: SkillProgress(
        defaultSkillTree,
        unlockedNodeIds: room.elements.map((id) => 'unlock_$id').toList(),
      ),
      initialEquippedElementsA: ['water', 'ice', 'shadow', 'wind'],
      initialEquippedElementsB: room.elements,
      initialApA: ApPool(max: 5, current: 5),
      initialApB: ApPool(max: 5, current: ap ?? room.initialAp),
      initialTurnsPlayedB: turn,
      initialLoadoutB: AttackLoadout(
        unlockedCombinationIds: room.attacks.toSet(),
        equippedCombinationIds: room.attacks,
      ),
      opponentBaseHp: room.hp,
    );

void main() {
  test('all patterns use equipped moves; elites can announce their trios', () {
    for (final room in DungeonRoom.all) {
      for (final move in [...room.pattern, ...room.enragedPattern]) {
        expect(['guard', ...room.elements, ...room.attacks], contains(move));
      }
      for (final (turn, move) in room.pattern.indexed) {
        final m = encounter(room, turn: turn, ap: 5);
        final intent = DungeonOpponent.plan(m, room);
        if (room.attacks.contains(move)) expect(intent.attackId, move);
        expect(m.cumulativeTurnsPlayedB, turn);
        expect(m.playerBAp, 5); // Planning never spends or regenerates AP.
        m.defend();
        expect(DungeonOpponent.resolve(m, intent), same(intent));
        m.previewAction(
          intent.elements,
          attackId: intent.attackId,
          defending: intent.defending,
        );
      }
    }
  });

  for (final entry in <String, List<String>>{
    'freeze': ['water', 'ice'],
    'silence': ['wind', 'shadow'],
    'AP drain': ['water', 'shadow'],
  }.entries) {
    test('${entry.key} interrupts the announced spell legally', () {
      final room = DungeonRoom.all[1];
      final m = encounter(room, turn: 2, ap: 2);
      final intent = DungeonOpponent.plan(m, room);
      expect(intent.attackId, 'glacial_prison');
      m.playElementIds(entry.value);
      final action = DungeonOpponent.resolve(m, intent);
      expect(action.interruption, isNotNull);
      expect(action.attackId, isNull);
      expect(action.thawing, entry.key == 'freeze');
      if (action.thawing) {
        m.thaw();
      } else {
        m.playElementIds(action.elements);
      }
      expect(m.isPlayerATurn, true);
      expect(m.playerBAp, greaterThanOrEqualTo(0));
      expect(() => DungeonOpponent.resolve(m, intent), throwsStateError);
    });
  }

  test('encounter keeps advertised intent until the enemy has acted', () {
    final c = DungeonCampaign(
      DungeonProgress()
          .prepare(['fire', 'wind'])
          .copyWith(active: true, room: 0, run: 1),
      DungeonProgressStore(),
    );
    final e = c.enter();
    final original = e.intent;
    e.match.playElementIds(['fire']);
    expect(e.intent, same(original));
    expect(e.chooseAction(), same(original));
    e.match.playElementIds(original.elements);
    expect(e.intent.elements, ['wind']);
    expect(e.intent, same(e.intent));
  });

  test('boss enrage never changes an already announced defense', () {
    final room = DungeonRoom.all.last;
    final m = encounter(room);
    DungeonIntent? committed;
    for (
      var turn = 0;
      turn < 40 && m.playerBCurrentHp * 2 > m.playerBMaxHp;
      turn++
    ) {
      committed = DungeonOpponent.plan(m, room);
      m.playElementIds(['water']);
      expect(DungeonOpponent.resolve(m, committed), same(committed));
      // Keep the fixture harmless while reaching the phase threshold.
      m.playElementIds(['water']);
    }
    expect(committed!.enraged, false);
    final next = DungeonOpponent.plan(m, room);
    expect(next.enraged, true);
    expect(next.defending, false);
  });
}
