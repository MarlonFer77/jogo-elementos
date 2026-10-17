import 'dart:convert';
import 'dart:math' as math;
import 'package:app/game_domain/beta_session.dart';
import 'package:app/game_domain/cosmetics.dart';
import 'package:app/game_domain/cosmetic_store.dart';
import 'package:app/game_presentation/beta_game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void advance(BetaSession run, double seconds) {
  for (var left = seconds; left > .000001; left -= 1 / 60) {
    run.update(math.min(left, 1 / 60));
  }
}

BetaSession arena([BetaLoadout loadout = const BetaLoadout()]) {
  final run = BetaSession(loadout: loadout)..start();
  run.enemies.clear();
  return run;
}

void main() {
  test(
    'Excalibur keeps combo color through impact; next unblessed attack resets it',
    () {
      final run = arena(const BetaLoadout(weapon: ShopUpgrade.excalibur));
      run.mix(BetaElement.wind);
      expect(run.selectedCombo, BetaCombo.firestorm);
      run.cast();
      advance(run, run.activeCastDuration + .02);
      expect(run.bladeCombo, BetaCombo.firestorm);
      run.element = BetaElement.earth;
      run.sword();
      advance(run, .17);
      expect(run.blessingTime, 0); // A miss consumes it too.
      expect(run.bladeElement, BetaElement.fire);
      expect(run.bladeCombo, BetaCombo.firestorm);
      advance(run, .4);
      run.sword();
      expect(run.bladeElement, BetaElement.earth);
      expect(run.bladeCombo, isNull);
      advance(run, .17);
      expect(run.bladeElement, BetaElement.earth);
      expect(run.bladeCombo, isNull);
    },
  );
  test(
    'v1 migrates without losing wallet, milestones or outfit; slots persist',
    () async {
      SharedPreferences.setMockInitialValues({
        CosmeticStore.key: jsonEncode({
          'version': 1,
          'coins': 2000,
          'claimedLevel': 5,
          'claimedClears': 2,
          'owned': ['traveler', 'ember'],
          'equipped': 'ember',
        }),
      });
      final before = await CosmeticStore().load();
      expect(before.slots, isEmpty);
      await Future.wait([
        CosmeticStore().buy('excalibur'),
        CosmeticStore().buy('excalibur'),
      ]);
      for (final id in [
        'spin',
        'leap',
        'somersault',
        'mercerus',
        'perseus',
        'angel',
      ]) {
        await CosmeticStore().buy(id);
        await CosmeticStore().equip(id);
      }
      await CosmeticStore().equip('excalibur');
      final saved = await CosmeticStore().load();
      expect(saved.coins, 550);
      expect(saved.claimedLevel, 5);
      expect(saved.claimedClears, 2);
      expect(saved.equipped, HeroOutfit.angel);
      expect(saved.slots[ShopSlot.sword], ShopUpgrade.leap);
      expect(saved.owned, contains('spin'));
      final game = BetaGame(outfit: saved.equipped, loadout: saved.loadout)
        ..restart();
      expect(game.session.loadout.attackBonus, 4);
      expect(game.session.loadout.agility, 10);
      expect(game.session.loadout.perseus, true);
      game.close();
      await CosmeticStore().unequip(ShopSlot.weapon);
      final removed = await CosmeticStore().load();
      expect(removed.loadout.attackBonus, 0);
      expect(removed.loadout.agility, 10);
      expect(removed.owned, contains('excalibur'));
      expect(removed.coins, saved.coins);
    },
  );

  test('techniques preserve hit timing, damage and forward-only range', () {
    for (final technique in [null, ShopUpgrade.spin, ShopUpgrade.leap]) {
      final run = arena(BetaLoadout(sword: technique));
      final front = BetaEnemy(BetaEnemyKind.brute, 0, 3.5)..windup = 10;
      final back = BetaEnemy(BetaEnemyKind.brute, 0, 6.5)..windup = 10;
      run.enemies.addAll([front, back]);
      expect(run.sword(), true);
      advance(run, .15);
      expect(front.hp, front.maxHp);
      advance(run, .02);
      expect(front.hp, front.maxHp - 13);
      expect(back.hp, back.maxHp);
      advance(run, .3);
      expect(front.hp, front.maxHp - 13);
    }
  });

  test(
    'Excalibur adds four; Merlin grants one nonstacking elemental charge',
    () {
      final run = arena(const BetaLoadout(weapon: ShopUpgrade.excalibur));
      run.element = BetaElement.water;
      expect(run.cast(), true);
      advance(run, .36);
      expect(run.blessingTime, closeTo(5, .03));
      expect(run.merlinTime, greaterThan(1));
      expect(run.blessingElement, BetaElement.water);
      run.projectiles.clear();
      final enemy = BetaEnemy(BetaEnemyKind.brute, 0, 3.5)..windup = 10;
      run.enemies.add(enemy);
      run.sword();
      advance(run, .17);
      expect(enemy.hp, enemy.maxHp - 20);
      expect(run.blessingTime, 0);
      advance(run, .4);
      run.sword();
      advance(run, .17);
      expect(enemy.hp, enemy.maxHp - 37);
      final expiring = arena(const BetaLoadout(weapon: ShopUpgrade.excalibur))
        ..cast();
      advance(expiring, 5.4);
      expect(expiring.blessingTime, 0);
      expect(expiring.merlinTime, 0);
    },
  );

  test(
    'Mercerus improves walking but mortal preserves dodge distance and iframe',
    () {
      final normal = arena()..setMovement(1, 0);
      final geared = arena(
        const BetaLoadout(
          cloak: ShopUpgrade.mercerus,
          dodge: ShopUpgrade.somersault,
        ),
      )..setMovement(1, 0);
      advance(normal, .2);
      advance(geared, .2);
      expect(geared.x, closeTo(normal.x * 1.1, .0001));
      normal.x = geared.x = 0;
      normal.dodge();
      geared.dodge();
      expect(geared.invulnerable, normal.invulnerable);
      advance(normal, .42);
      advance(geared, .42);
      expect(geared.x, closeTo(normal.x, .0001));
      expect(geared.dodgeCooldown, closeTo(normal.dodgeCooldown, .0001));
    },
  );

  for (final kind in [BetaEnemyKind.guardian, BetaEnemyKind.darkElf]) {
    test('Perseus blocks $kind status, not impact; dodging blocks both', () {
      for (final armor in [false, true]) {
        final run = arena(
          BetaLoadout(armor: armor ? ShopUpgrade.perseus : null),
        );
        final enemy = BetaEnemy(kind, 0, 4)..beginAttack(0, 5);
        enemy.windup = .01;
        run.enemies.add(enemy);
        run.update(.02);
        expect(run.hp, closeTo(100 - kind.damage, .05));
        expect(
          run.sounds.where((event) => event == BetaSound.ward),
          hasLength(armor ? 1 : 0),
        );
        expect(run.wardTime, armor ? greaterThan(0) : 0);
        expect(
          kind == BetaEnemyKind.guardian ? run.burnTime : run.curseTime,
          armor ? 0 : greaterThan(0),
        );
        enemy.cooldown = 100;
        run.pause();
        final paused = (run.hp, run.burnTime, run.curseTime, run.wardTime);
        advance(run, 1);
        expect((run.hp, run.burnTime, run.curseTime, run.wardTime), paused);
        run.resume();
        run.mana = 20;
        advance(run, 1);
        expect(run.wardTime, 0);
        if (kind == BetaEnemyKind.guardian) {
          expect(run.hp, closeTo(100 - kind.damage - (armor ? 0 : 2), .05));
        } else {
          expect(run.mana, closeTo(armor ? 29 : 24.5, .05));
        }
        advance(run, 4);
        expect(run.burnTime + run.curseTime, 0);
      }
      final run = arena()..invulnerable = .5;
      run.enemies.add(
        BetaEnemy(kind, 0, 4)
          ..beginAttack(0, 5)
          ..windup = .01,
      );
      run.update(.02);
      expect(run.hp, 100);
      expect(run.burnTime + run.curseTime, 0);
    });
  }
}
