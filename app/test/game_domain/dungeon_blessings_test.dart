import 'dart:async';
import 'dart:convert';
import 'package:app/game_domain/dungeon_blessings.dart';
import 'package:app/game_domain/dungeon_campaign.dart';
import 'package:app/game_domain/dungeon_progress.dart';
import 'package:app/game_domain/dungeon_progress_store.dart';
import 'package:app/game_domain/training_match.dart';
import 'package:battle_engine/battle_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

DungeonProgress pending(int room) => DungeonProgress()
    .prepare(['fire', 'wind'])
    .copyWith(active: true, run: 1, room: room);
DungeonProgress chooseAll(DungeonProgress p, List<String> ids) {
  for (final id in ids) {
    p = p.chooseBlessing(id);
  }
  return p;
}

void win(DungeonEncounter e) {
  final m = e.match;
  for (var i = 0; i < 160 && !m.isOver; i++) {
    if (m.isPlayerATurn) {
      m.playElementIds(
        m.availableApForAction >= 3 ? ['fire', 'wind'] : ['fire'],
      );
    } else {
      m.defend();
    }
  }
  expect(m.playerAWon, true);
}

class ControlledStore extends DungeonProgressStore {
  bool fail = false;
  Completer<void>? hold;
  @override
  Future<void> save(DungeonProgress p) async {
    if (hold != null) await hold!.future;
    if (fail) throw StateError('disk');
    await super.save(p);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'milestone and pending offer survive restart; claim is saved once',
    () async {
      final store = DungeonProgressStore();
      final c = DungeonCampaign(pending(2), store);
      final e = c.enter();
      win(e);
      await c.complete(e);
      expect(c.progress.pendingAltar, 3);
      expect(() => c.enter(), throwsStateError);
      await expectLater(c.complete(e), throwsStateError);
      final restored = DungeonCampaign(await store.load(), store);
      expect(
        restored.progress.blessingOffers.map((b) => b.id),
        c.progress.blessingOffers.map((b) => b.id),
      );
      await expectLater(
        Future.sync(() => restored.chooseBlessing('trinity_echo')),
        throwsStateError,
      );
      await restored.chooseBlessing('first_spark');
      await expectLater(
        Future.sync(() => restored.chooseBlessing('first_spark')),
        throwsStateError,
      );
      expect((await store.load()).blessings, ['first_spark']);
      expect(restored.progress.xp, e.room.xp);
      final next = restored.enter();
      expect(next.match.playerAAp, 1);
      expect(next.match.playerACurrentHp, restored.progress.hp);
      expect(next.match.playerBMaxHp, DungeonRoom.all[3].hp);
      restored.leave(next);
      expect(
        restored.enter().match.playerAAp,
        1,
      ); // same checkpoint, no stacking
    },
  );

  test(
    'failed/concurrent claims never advance memory or duplicate choices',
    () async {
      final store = ControlledStore();
      final c = DungeonCampaign(pending(3), store);
      store.fail = true;
      await expectLater(c.chooseBlessing('opening_ember'), throwsStateError);
      expect(c.progress.blessings, isEmpty);
      store.fail = false;
      store.hold = Completer<void>();
      final first = c.chooseBlessing('opening_ember');
      await expectLater(c.chooseBlessing('first_spark'), throwsStateError);
      expect(c.progress.pendingAltar, 3);
      store.hold!.complete();
      await first;
      expect((await store.load()).blessings, ['opening_ember']);
    },
  );

  test(
    'v1 migration preserves gains; invalid orders and inactive grants are rejected',
    () async {
      final old = {...pending(7).copyWith(xp: 300).toJson(), 'version': 1}
        ..remove('blessings');
      SharedPreferences.setMockInitialValues({
        DungeonProgressStore.key: jsonEncode(old),
      });
      final loaded = await DungeonProgressStore().load();
      expect(loaded.xp, 300);
      expect(loaded.room, 7);
      expect(loaded.pendingAltar, 3);
      final chosen = chooseAll(loaded, ['first_spark', 'deep_reserve']);
      expect(chosen.pendingAltar, isNull);
      expect(chosen.toJson()['version'], DungeonProgress.saveVersion);
      for (final ids in [
        ['unknown'],
        ['deep_reserve'],
        ['first_spark', 'first_spark'],
      ]) {
        expect(
          () =>
              DungeonProgress.fromJson({...loaded.toJson(), 'blessings': ids}),
          throwsFormatException,
        );
      }
      expect(
        () => DungeonProgress.fromJson({...chosen.toJson(), 'active': false}),
        throwsFormatException,
      );
    },
  );

  test(
    'opening bonuses and AP are temporary and never granted to the enemy',
    () async {
      final energy = DungeonCampaign(
        chooseAll(pending(9), ['first_spark', 'deep_reserve', 'last_breath']),
        DungeonProgressStore(),
      );
      final e = energy.enter();
      expect(e.match.playerAAp, 3);
      expect(e.match.playerAApMax, 6);
      expect(e.match.playerBApMax, 5);
      expect(e.match.startNewBattleKeepingProgress().playerAApMax, 5);
      energy.leave(e);
      await energy.abandon();
      expect(energy.progress.blessings, isEmpty);
      await energy.start();
      expect(energy.enter().match.playerAAp, 0);
      final shield = DungeonCampaign(
        pending(3).chooseBlessing('pilgrim_shield'),
        DungeonProgressStore(),
      ).enter().match;
      expect(shield.playerAActiveStatuses.any((s) => s.id == 'shield'), true);
      shield.playElementIds(['fire']);
      shield.playElementIds(['fire']);
      expect(shield.playerACurrentHp, 100);
      final buff = DungeonCampaign(
        pending(3).chooseBlessing('opening_ember'),
        DungeonProgressStore(),
      ).enter().match;
      expect(buff.previewAction(['fire']).opponentHpLoss, 7);
      buff.playElementIds(['fire']);
      expect(buff.playerAActiveStatuses.any((s) => s.id == 'buff'), false);
      expect(TrainingMatch().playerAActiveStatuses, isEmpty);
    },
  );

  test(
    'combo grants share preview/execution and never apply on enemy/basic/fizzle',
    () {
      final p = chooseAll(pending(9), [
        'first_spark',
        'woven_guard',
        'quiet_oath',
      ]);
      final m = DungeonCampaign(p, DungeonProgressStore()).enter().match;
      m.playElementIds(['fire']);
      expect(m.playerAActiveStatuses.any((s) => s.id == 'guard'), false);
      m.defend();
      final preview = m.previewAction(['fire', 'wind']);
      expect(preview.effects.any((s) => s.contains('Enfraquecimento')), true);
      expect(preview.effects.any((s) => s.contains('Defesa')), true);
      m.playElementIds(['fire', 'wind']);
      expect(m.playerAActiveStatuses.any((s) => s.id == 'guard'), true);
      expect(m.playerBActiveStatuses.any((s) => s.id == 'debuff'), true);
      m.playElementIds(['fire']);
      expect(m.playerACurrentHp, 98); // ceil(ceil(5 * .75) / 2)
      for (var i = 0; i < 2; i++) {
        m.playElementIds(['fire']);
        m.defend();
      }
      m.beginSeal(['fire', 'wind']);
      m.resolveSeal([]);
      expect(m.playerAActiveStatuses.any((s) => s.id == 'guard'), false);
    },
  );

  test('damage blessings only alter the intended damaging recipe size', () {
    final duo = defaultCombinationBook.combinations
        .firstWhere((c) => c.elements.length == 2 && c.damage > 0)
        .result;
    final triple = defaultCombinationBook.combinations
        .firstWhere((c) => c.elements.length == 3 && c.damage > 0)
        .result;
    final twin = DungeonBlessings.byId('twin_runes')!.modifier!;
    final trinity = DungeonBlessings.byId('trinity_echo')!.modifier!;
    expect(twin.apply(duo).damage, duo.damage + 3);
    expect(twin.apply(triple).damage, triple.damage);
    expect(trinity.apply(triple).damage, (triple.damage * 1.2).ceil());
    expect(trinity.apply(duo).damage, duo.damage);
    expect(twin.apply(duo.copyWith(damage: 0)).damage, 0);
    final match = TrainingMatch(
      initialProgressA: SkillProgress(
        defaultSkillTree,
        unlockedNodeIds: ['unlock_fire', 'unlock_wind'],
      ),
      initialApA: const ApPool(max: 5, current: 3),
      temporaryModifiersA: [twin],
    );
    final preview = match.previewAction(['fire', 'wind']);
    match.playElementIds(['fire', 'wind']);
    final base = defaultCombinationBook.resolve([
      Elements.fire,
      Elements.wind,
    ])!.damage;
    expect(preview.opponentHpLoss, base + 3);
    expect(match.playerBCurrentHp, 100 - preview.opponentHpLoss);
  });

  test(
    'final victory clears blessings without changing XP or permanent nodes',
    () async {
      final c = DungeonCampaign(
        chooseAll(pending(9), ['first_spark', 'deep_reserve', 'last_breath']),
        DungeonProgressStore(),
      );
      final nodes = c.progress.nodes;
      final e = c.enter();
      win(e);
      await c.complete(e);
      expect(c.progress.blessings, isEmpty);
      expect(c.progress.active, false);
      expect(c.progress.nodes, nodes);
      expect(c.progress.xp, e.room.xp);
    },
  );

  test('defeat clears temporary grants but keeps prior XP', () async {
    final c = DungeonCampaign(
      pending(3).copyWith(hp: 1, xp: 170).chooseBlessing('first_spark'),
      DungeonProgressStore(),
    );
    final e = c.enter();
    e.match.playElementIds(['fire']);
    e.match.playElementIds(['fire']);
    expect(e.match.playerAWon, false);
    await c.complete(e);
    expect(c.progress.blessings, isEmpty);
    expect(c.progress.xp, 170);
    expect(c.progress.active, false);
  });
}
