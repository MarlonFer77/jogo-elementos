import 'package:app/game_domain/dungeon_campaign.dart';
import 'package:app/game_domain/dungeon_progress.dart';
import 'package:app/game_domain/dungeon_progress_store.dart';
import 'package:app/game_domain/training_match.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

DungeonProgress prepared() => DungeonProgress().prepare(['fire', 'wind']);

void winFirstRoom(TrainingMatch match) {
  for (var i = 0; i < 100 && !match.isOver; i++) {
    if (match.currentPlayerIsFrozen) {
      match.thaw();
      continue;
    }
    if (match.isPlayerATurn && match.availableApForAction >= 3) {
      match.playElementIds(['fire', 'wind']);
    } else {
      match.playElementIds([match.equippedElementIdsForCurrentPlayer.first]);
    }
  }
  expect(match.playerBCurrentHp, 0);
}

class FailingStore extends DungeonProgressStore {
  bool fail = false;
  @override
  Future<void> save(DungeonProgress p) async {
    if (fail) throw StateError('disk');
    await super.save(p);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(
    () => SharedPreferences.setMockInitialValues({
      'training_unlocked_a': ['unlock_water'],
    }),
  );

  test('level thresholds, points and prerequisites are enforced', () {
    final p = prepared();
    expect(p.points, 0);
    expect(() => p.unlock('unlock_ice'), throwsStateError);
    expect(p.copyWith(xp: 99).level, 1);
    expect(p.copyWith(xp: 100).level, 2);
    expect(p.copyWith(xp: 250).level, 3);
    expect(p.copyWith(xp: 250).levelXp, 0);
    expect(() => p.copyWith(xp: 250).unlock('wildfire_path'), throwsStateError);
    final next = p
        .copyWith(xp: 250)
        .unlock('ember_mastery')
        .unlock('unlock_ice');
    expect(next.points, 0);
    expect(next.elements, contains('ice'));
    expect(() => next.unlock('ember_mastery'), throwsStateError);
    expect(
      () => p.copyWith(xp: 250).unlock('unstable_core_training'),
      throwsStateError,
    );
    expect(DungeonProgress.fromJson(next.toJson()).nodes, next.nodes);
  });

  test(
    'victory saved once, restored at next room; training untouched',
    () async {
      final store = DungeonProgressStore();
      final c = DungeonCampaign(prepared(), store);
      await c.start();
      final encounter = c.enter();
      await expectLater(c.complete(encounter), throwsStateError);
      winFirstRoom(encounter.match);
      await c.complete(encounter);
      await expectLater(c.complete(encounter), throwsStateError);
      final restored = await store.load();
      expect(restored.xp, 40);
      expect(restored.room, 1);
      expect(restored.attacks, ['ignited_storm']);
      expect(
        (await SharedPreferences.getInstance()).getStringList(
          'training_unlocked_a',
        ),
        ['unlock_water'],
      );
      final continued = DungeonCampaign(restored, store).enter();
      expect(continued.match.playerACurrentHp, restored.hp);
      expect(continued.room.name, 'Sentinela Glacial');
    },
  );

  test('failed save can retry without spending or rewarding twice', () async {
    final store = FailingStore();
    final c = DungeonCampaign(prepared(), store);
    await c.start();
    final encounter = c.enter();
    winFirstRoom(encounter.match);
    store.fail = true;
    await expectLater(c.complete(encounter), throwsStateError);
    expect(c.progress.xp, 0);
    store.fail = false;
    await c.complete(encounter);
    expect(c.progress.xp, 40);
    final leveled = DungeonCampaign(prepared().copyWith(xp: 100), store);
    store.fail = true;
    await expectLater(leveled.unlock('unlock_ice'), throwsStateError);
    expect(leveled.progress.points, 1);
  });

  test('leaving, defeat and stale encounters grant no XP', () async {
    final c = DungeonCampaign(
      prepared().copyWith(xp: 40),
      DungeonProgressStore(),
    );
    await c.start();
    final old = c.enter();
    c.leave(old);
    final encounter = c.enter();
    await expectLater(c.complete(old), throwsStateError);
    for (var i = 0; i < 120 && !encounter.match.isOver; i++) {
      final m = encounter.match;
      if (m.currentPlayerIsFrozen) {
        m.thaw();
      } else if (m.isPlayerATurn) {
        m.defend();
      } else if (m.availableApForAction >= 3) {
        m.playEquippedAttack('ignited_storm');
      } else {
        m.playElementIds(['fire']);
      }
    }
    expect(encounter.match.playerACurrentHp, 0);
    await c.complete(encounter);
    expect(c.progress.xp, 40);
    expect(c.progress.active, false);
    expect(
      c.progress.attacks,
      isEmpty,
    ); // AI discoveries never become player rewards.
  });

  test('AI plays legally until an encounter ends', () async {
    final c = DungeonCampaign(prepared(), DungeonProgressStore());
    await c.start();
    final m = c.enter().match;
    for (var turn = 0; turn < 120 && !m.isOver; turn++) {
      if (m.currentPlayerIsFrozen) {
        m.thaw();
      } else if (m.isPlayerATurn) {
        m.playElementIds(
          m.availableApForAction >= 3 ? ['fire', 'wind'] : ['fire'],
        );
      } else {
        final a = DungeonOpponent.choose(m);
        if (a.defending) {
          m.defend();
        } else if (a.attackId != null) {
          m.playEquippedAttack(a.attackId!);
        } else {
          m.playElementIds(a.elements);
        }
      }
    }
    expect(m.isOver, true);
    expect(m.playerAAp, greaterThanOrEqualTo(0));
    expect(m.playerBAp, greaterThanOrEqualTo(0));
  });

  test(
    'ten rooms complete, boss pays once and a new run starts healthy',
    () async {
      final c = DungeonCampaign(
        prepared()
            .copyWith(xp: 450)
            .unlock('ember_mastery')
            .unlock('guard_training')
            .unlock('vitality_training'),
        DungeonProgressStore(),
      );
      await c.start();
      for (var room = 0; room < DungeonRoom.all.length; room++) {
        final encounter = c.enter();
        final m = encounter.match;
        for (var turn = 0; turn < 150 && !m.isOver; turn++) {
          if (m.currentPlayerIsFrozen) {
            m.thaw();
          } else if (m.isPlayerATurn) {
            m.playElementIds(
              m.availableApForAction >= m.attackApCost(2) &&
                      !m.currentPlayerIsSilenced
                  ? ['fire', 'wind']
                  : ['fire'],
            );
          } else {
            final a = DungeonOpponent.choose(m);
            if (a.defending) {
              m.defend();
            } else if (a.attackId != null) {
              m.playEquippedAttack(a.attackId!);
            } else {
              m.playElementIds(a.elements);
            }
          }
        }
        expect(m.playerAWon, true, reason: 'room $room');
        await c.complete(encounter);
        await expectLater(c.complete(encounter), throwsStateError);
        expect(c.progress.active, room < DungeonRoom.all.length - 1);
        expect((await c.store.load()).room, c.progress.room);
      }
      expect(c.progress.xp, 450 + DungeonRoom.totalXp);
      expect(c.progress.clears, 1);
      expect(c.progress.active, false);
      await c.start();
      expect(c.progress.hp, c.progress.maxHp);
      expect(c.progress.room, 0);
    },
  );

  test('corrupted saves are preserved, not silently reset', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(DungeonProgressStore.key, '{broken');
    await expectLater(DungeonProgressStore().load(), throwsStateError);
    expect(prefs.getString(DungeonProgressStore.key), '{broken');
  });

  test(
    'ten valid rooms increase HP, rewards and starting AP; old saves survive',
    () {
      expect(DungeonRoom.all.length, 10);
      expect(DungeonRoom.totalXp, 1000);
      var hp = 0, xp = 0, ap = 0;
      for (final (index, room) in DungeonRoom.all.indexed) {
        expect(room.hp, greaterThan(hp));
        expect(room.xp, greaterThan(xp));
        expect(room.initialAp, inInclusiveRange(ap, 5));
        final p = prepared().copyWith(active: true, run: 1, room: index);
        expect(DungeonProgress.fromJson(p.toJson()).room, index);
        final m = DungeonCampaign(p, DungeonProgressStore()).enter().match;
        expect(m.playerBMaxHp, room.hp);
        expect(m.playerBAp, room.initialAp);
        m.playElementIds(['fire']);
        expect(m.equippedAttacksForCurrentPlayer.length, room.attacks.length);
        expect(room.attacks.length, inInclusiveRange(1, 3));
        expect(room.elements.length, inInclusiveRange(2, 4));
        for (final attack in m.equippedAttacksForCurrentPlayer) {
          expect(room.elements, containsAll(attack.elementIds));
        }
        hp = room.hp;
        xp = room.xp;
        ap = room.initialAp;
      }
      final oldSave = prepared()
          .copyWith(xp: 100, room: 2, active: true, run: 1)
          .toJson();
      expect(DungeonProgress.fromJson(oldSave).xp, 100);
      expect(
        () => DungeonProgress.fromJson({...oldSave, 'room': 10}),
        throwsFormatException,
      );
    },
  );
}
