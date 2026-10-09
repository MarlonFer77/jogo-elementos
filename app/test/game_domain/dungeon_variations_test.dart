import 'dart:async';
import 'dart:math';
import 'package:app/game_domain/dungeon_campaign.dart';
import 'package:app/game_domain/dungeon_progress.dart';
import 'package:app/game_domain/dungeon_progress_store.dart';
import 'package:app/game_domain/dungeon_variations.dart';
import 'package:battle_engine/battle_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dungeon_opponent_test.dart' as fixtures;
import 'dungeon_blessings_test.dart' show ControlledStore, win;

DungeonProgress prepared() => DungeonProgress().prepare(['fire', 'wind']);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    '30 variants preserve the curve, legal recipes and actionable patterns',
    () {
      for (var i = 0; i < 10; i++) {
        final base = DungeonRoom.all[i];
        final patterns = <String>{};
        for (final tactic in DungeonTactic.values) {
          final room = DungeonVariations.room(i, tactic.name);
          expect(
            [room.hp, room.xp, room.initialAp, room.arena, room.appearance],
            [base.hp, base.xp, base.initialAp, base.arena, base.appearance],
          );
          expect(room.tactic, tactic);
          expect(room.elements.length, inInclusiveRange(2, 4));
          expect(room.attacks.length, inInclusiveRange(1, 3));
          patterns.add(room.pattern.join(','));
          for (final id in room.attacks) {
            final recipe = defaultCombinationBook.combinations.firstWhere(
              (c) => c.resultId == id,
            );
            expect(
              room.elements,
              containsAll(recipe.elements.map((e) => e.id)),
            );
          }
          for (final pattern in [room.pattern, room.enragedPattern]) {
            for (final move in pattern) {
              expect([
                'guard',
                ...room.elements,
                ...room.attacks,
              ], contains(move));
            }
          }
          for (final (turn, move) in room.pattern.indexed) {
            final m = fixtures.encounter(room, turn: turn, ap: 5);
            final intent = DungeonOpponent.plan(m, room);
            if (room.attacks.contains(move)) expect(intent.attackId, move);
            m.defend();
            expect(DungeonOpponent.resolve(m, intent), same(intent));
            m.previewAction(
              intent.elements,
              attackId: intent.attackId,
              defending: intent.defending,
            );
          }
          final m = fixtures.encounter(room);
          for (var turn = 0; turn < 180 && !m.isOver; turn++) {
            final intent = DungeonOpponent.plan(m, room);
            if (m.currentPlayerIsFrozen) {
              m.thaw();
            } else {
              m.playElementIds(['water']);
            }
            if (m.isOver) break;
            final action = DungeonOpponent.resolve(m, intent);
            if (action.thawing) {
              m.thaw();
            } else if (action.defending) {
              m.defend();
            } else if (action.attackId != null) {
              m.playEquippedAttack(action.attackId!);
            } else {
              m.playElementIds(action.elements);
            }
            expect(m.playerBAp, greaterThanOrEqualTo(0));
          }
          expect(m.isOver, true, reason: '${room.name} / ${tactic.name}');
          if (i == 9) expect(room.enragedPattern, isNotEmpty);
        }
        expect(patterns.length, 3);
      }
    },
  );

  test(
    'route balances each tier and survives re-entry, restart and rewards',
    () async {
      final routes = <String>{};
      for (var seed = 0; seed < 20; seed++) {
        final route = DungeonVariations.roll(Random(seed));
        expect(route.length, 10);
        for (final offset in [0, 3, 6]) {
          expect(
            route.skip(offset).take(3).toSet(),
            DungeonTactic.values.map((t) => t.name).toSet(),
          );
        }
        routes.add(route.join(','));
      }
      expect(routes.length, greaterThan(1));
      final store = DungeonProgressStore();
      final c = DungeonCampaign(prepared(), store, random: Random(4));
      await c.start();
      final route = c.progress.encounters;
      final e = c.enter();
      c.leave(e);
      expect(c.enter().room.pattern, e.room.pattern);
      final restored = DungeonCampaign(
        await store.load(),
        store,
        random: Random(999),
      );
      final battle = restored.enter();
      expect(battle.room.pattern, e.room.pattern);
      win(battle);
      await restored.complete(battle);
      expect((await store.load()).encounters, route);
      await restored.abandon();
      expect((await store.load()).encounters, isEmpty);
      await restored.start();
      expect(restored.progress.run, 2);
      expect(restored.progress.encounters.length, 10);
    },
  );

  test('legacy encounters stay unchanged; invalid routes never load', () {
    final p = prepared().copyWith(active: true, run: 1);
    for (final version in [1, 2]) {
      final old = {...p.toJson(), 'version': version}..remove('encounters');
      if (version == 1) old.remove('blessings');
      final loaded = DungeonProgress.fromJson(old);
      expect(loaded.encounters, isEmpty);
      expect(loaded.roomAt(0), same(DungeonRoom.all.first));
      expect(
        DungeonProgress.fromJson(loaded.toJson()).roomAt(0).tactic,
        isNull,
      );
    }
    for (final route in [
      ['assault'],
      List.filled(10, 'unknown'),
    ]) {
      expect(
        () => DungeonProgress.fromJson({...p.toJson(), 'encounters': route}),
        throwsFormatException,
      );
    }
    expect(
      () => DungeonProgress.fromJson({
        ...p.toJson(),
        'encounters': DungeonVariations.roll(Random(1)),
        'active': false,
      }),
      throwsFormatException,
    );
  });

  test('save failure and double start do not advance an expedition', () async {
    final store = ControlledStore()..fail = true;
    final c = DungeonCampaign(prepared(), store);
    await expectLater(c.start(), throwsStateError);
    expect(c.progress.active, false);
    expect(c.progress.encounters, isEmpty);
    store.fail = false;
    store.hold = Completer<void>();
    final saving = c.start();
    await expectLater(c.start(), throwsStateError);
    expect(() => c.enter(), throwsStateError);
    store.hold!.complete();
    await saving;
    expect(c.progress.run, 1);
    expect((await store.load()).encounters, c.progress.encounters);
  });

  test(
    'camp loadout validates unlocks, slots and persists before battle',
    () async {
      final store = ControlledStore();
      final c = DungeonCampaign(
        prepared().copyWith(
          xp: 700,
          nodes: [
            'unlock_fire',
            'unlock_wind',
            'unlock_water',
            'unlock_ice',
            'unlock_earth',
          ],
          attacks: ['ignited_storm', 'glacial_prison', 'quagmire', 'eruption'],
        ),
        store,
      );
      for (final elements in [
        <String>[],
        ['fire', 'fire'],
        ['shadow'],
        ['fire', 'wind', 'water', 'ice', 'earth'],
      ]) {
        expect(() => c.equip(elements: elements), throwsStateError);
      }
      for (final attacks in [
        ['missing'],
        ['lava'],
        ['ignited_storm', 'ignited_storm'],
        c.progress.attacks,
      ]) {
        expect(() => c.equip(attacks: attacks), throwsStateError);
      }
      store.fail = true;
      await expectLater(c.equip(elements: ['water']), throwsStateError);
      expect(c.progress.elements, ['fire', 'wind']);
      store.fail = false;
      await c.equip(elements: ['water', 'ice'], attacks: ['glacial_prison']);
      final loaded = await store.load();
      expect(loaded.elements, ['water', 'ice']);
      expect(loaded.equippedAttacks, ['glacial_prison']);
      await c.start();
      final e = c.enter();
      expect(e.match.equippedElementIdsForPlayerA, ['water', 'ice']);
      expect(e.match.equippedAttackIdsForPlayerA, ['glacial_prison']);
      expect(() => c.equip(elements: ['fire']), throwsStateError);
    },
  );
}
