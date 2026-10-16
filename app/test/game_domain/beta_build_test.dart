import 'dart:math' as math;
import 'package:app/game_domain/beta_session.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/beta_puzzle_fixture.dart';

void advance(BetaSession run, double seconds) {
  for (var left = seconds; left > .00001; left -= 1 / 60) {
    run.update(math.min(left, 1 / 60));
  }
}

BetaEnemy target(BetaSession run) {
  final enemy = BetaEnemy(BetaEnemyKind.guardian, 0, 3.4)..cooldown = 100;
  run.enemies
    ..clear()
    ..add(enemy);
  return enemy;
}

void impact(BetaSession run, BetaCombo combo) {
  final enemy = target(run);
  run.projectiles.add(
    BetaProjectile(enemy.x, enemy.z, 0, -1, combo.first, combo: combo),
  );
  run.update(.01);
}

void earnPoints(BetaSession run) {
  run.enemies
    ..clear()
    ..addAll([
      for (var i = 0; i < 2; i++)
        BetaEnemy(BetaEnemyKind.guardian, i * 2.0, -7)
          ..hp = .01
          ..burn = 1,
    ]);
  run.update(.01);
  run.pause();
}

void main() {
  test(
    'six unordered recipes, distinct casts, one cost and discovery per hit',
    () {
      for (final combo in BetaCombo.values) {
        expect(BetaCombo.resolve(combo.first, combo.second), combo);
        expect(BetaCombo.resolve(combo.second, combo.first), combo);
        expect(BetaCombo.resolve(combo.first, combo.first), isNull);
        expect(BetaCombo.resolve(combo.first, null), isNull);
        final run = BetaSession()..start();
        target(run);
        run.select(combo.second);
        run.mix(combo.first);
        expect(run.selectedCombo, combo);
        run.mana = combo.mana - 1.0;
        expect(run.request(BetaAction.cast), false);
        run.mana = 100;
        expect(run.cast(), true);
        expect(run.mana, 100 - combo.mana);
        expect(run.activeCastDuration, combo.castTime);
        expect(run.spellCooldown, combo.cooldown);
        expect(run.cast(), false);
        run.select(
          BetaElement.earth,
        ); // Cannot change a spell during its channel.
        expect(run.selectedCombo, combo);
        advance(run, combo.castTime + .2);
        expect(run.discoveredCombos, {combo});
        expect(run.equippedCombos, [combo]);
        expect(run.sounds.where((s) => s == BetaSound.discovery), hasLength(1));
      }
    },
  );

  test('combos apply their damage and utility only on contact', () {
    for (final combo in BetaCombo.values) {
      final run = BetaSession()..start();
      run.hp = 50;
      impact(run, combo);
      final enemy = run.enemies.single;
      expect(enemy.hp, closeTo(190 - combo.damage, .04));
      expect(run.hp, 50 + combo.heal);
      expect(enemy.burn, closeTo(combo.burn, .02));
      expect(enemy.slow, closeTo(combo.slow, .02));
      expect(run.protection, combo.ward);
      expect(enemy.pushTime > 0, combo.push > 0);
    }
    for (final kind in [BetaEnemyKind.goblin, BetaEnemyKind.guardian]) {
      final run = BetaSession()..start();
      final enemy = BetaEnemy(kind, 0, 3.5)..beginAttack(0, 5);
      enemy.cooldown = 0;
      run.enemies
        ..clear()
        ..add(enemy);
      run.projectiles.add(
        BetaProjectile(
          0,
          3.5,
          0,
          -1,
          BetaElement.wind,
          combo: BetaCombo.shards,
        ),
      );
      run.update(.01);
      expect(enemy.windup, 0);
      expect(enemy.cooldown, closeTo(enemy.boss ? .24 : .79, .001));
    }
  });

  test('area damage respects cover and scales only secondary targets', () {
    final run = BetaSession()..start();
    final primary = BetaEnemy(BetaEnemyKind.goblin, 2.8, 2.2)..cooldown = 100;
    final exposed = BetaEnemy(BetaEnemyKind.goblin, 1.2, 2.2)..cooldown = 100;
    final covered = BetaEnemy(BetaEnemyKind.goblin, 4.9, 2.2)..cooldown = 100;
    run.enemies
      ..clear()
      ..addAll([primary, exposed, covered]);
    run.projectiles.add(
      BetaProjectile(2.8, 2.9, 0, -1, BetaElement.water, combo: BetaCombo.mist),
    );
    run.update(.01);
    expect(primary.hp, 18);
    expect(exposed.hp, 26);
    expect(covered.hp, 38);
  });

  test('wall and missed casts do not discover, heal or grant skill buffs', () {
    final run = BetaSession();
    run.learnSkill(BetaSkill.runicBlade);
    run.start();
    run.enemies.clear();
    run.hp = 50;
    run.projectiles.add(
      BetaProjectile(4, 3.1, 0, -1, BetaElement.fire, combo: BetaCombo.steam),
    );
    advance(run, .2);
    expect(run.effects.any((e) => e.kind == BetaEffectKind.blocked), true);
    expect(run.discoveredCombos, isEmpty);
    expect(run.hp, 50);
    expect(run.runicBladeTime, 0);
    run.select(BetaElement.fire);
    run.mix(BetaElement.water);
    expect(run.cast(), true);
    advance(run, 1.9);
    expect(run.discoveredCombos, isEmpty);
    expect(run.hp, 50);
    expect(run.runicBladeTime, 0);
  });

  test(
    'fourth discovery requires a safe replacement; slots cannot be bypassed',
    () {
      final run = BetaSession()..start();
      for (final combo in BetaCombo.values.take(4)) {
        impact(run, combo);
      }
      expect(run.discoveredCombos, hasLength(4));
      expect(run.equippedCombos, BetaCombo.values.take(3));
      run.select(BetaCombo.mist.first);
      run.mix(BetaCombo.mist.second);
      final mana = run.mana;
      expect(run.spellEquipped, false);
      expect(run.canRequest(BetaAction.cast), false);
      expect(run.cast(), false);
      expect(run.mana, mana);
      expect(run.selectCombo(BetaCombo.mist), false);
      expect(run.equipCombo(BetaCombo.mist, replaceSlot: 0), false);
      run.pause();
      expect(run.equipCombo(BetaCombo.mist, replaceSlot: 0), false);
      run.enemies.clear();
      expect(run.equipCombo(BetaCombo.mist), false);
      expect(run.equipCombo(BetaCombo.mist, replaceSlot: -1), false);
      expect(run.equipCombo(BetaCombo.mist, replaceSlot: 3), false);
      expect(run.equipCombo(BetaCombo.mud, replaceSlot: 0), false);
      expect(run.equipCombo(BetaCombo.steam, replaceSlot: 0), false);
      expect(run.equipCombo(BetaCombo.mist, replaceSlot: 0), true);
      expect(() => run.equippedCombos.clear(), throwsUnsupportedError);
      expect(() => run.discoveredCombos.clear(), throwsUnsupportedError);
      run.resume();
      expect(run.selectCombo(BetaCombo.mist), true);
      expect(run.canCast, true);
      run.select(BetaElement.fire);
      run.mix(BetaElement.water);
      expect(run.canCast, false); // The replaced combo is no longer usable.
    },
  );

  test('skill requirements, earned points and no repeated purchases', () {
    final run = BetaSession();
    expect(run.skillPoints, 1);
    expect(run.learnSkill(BetaSkill.pursuit), false);
    expect(run.learnSkill(BetaSkill.runicBlade), true);
    expect(run.skillPoints, 0);
    expect(run.learnSkill(BetaSkill.runicBlade), false);
    expect(run.learnSkill(BetaSkill.ward), false);
    run.start();
    earnPoints(run);
    expect(run.level, 3);
    expect(run.skillPoints, 2);
    expect(run.learnSkill(BetaSkill.flow), false); // Missing prerequisite.
    expect(run.learnSkill(BetaSkill.pursuit), true);
    run.resume();
    expect(run.learnSkill(BetaSkill.ward), false); // Must pause in a safe area.
    advance(run, .5);
    expect(run.skillPoints, 1); // Dead enemies never award XP twice.
    run.pause();
    expect(run.learnSkill(BetaSkill.ward), true);
    expect(run.skillPoints, 0);
  });

  test('Vanguarda empowers one swing and returns dodge recovery once', () {
    final run = BetaSession()..learnSkill(BetaSkill.runicBlade);
    run.start();
    earnPoints(run);
    run.learnSkill(BetaSkill.pursuit);
    run.resume();
    impact(run, BetaCombo.steam);
    expect(run.runicBladeTime, 4);
    final enemy = target(run);
    final before = enemy.hp;
    run.dodgeCooldown = 1.5;
    run.sword();
    advance(run, .17);
    expect(before - enemy.hp, 25); // Level 3: 17 + 8.
    expect(run.runicBladeTime, 0);
    expect(run.dodgeCooldown, closeTo(.73, .001));
    advance(run, .4);
    final after = enemy.hp;
    run.sword();
    advance(run, .17);
    expect(after - enemy.hp, 17);
    run.enemies.clear();
    run.runicBladeTime = 4;
    advance(run, .4);
    run.sword();
    advance(run, .17);
    expect(run.runicBladeTime, 0); // Missing also consumes the opportunity.
  });

  test('Guardião converts earned protection into longer invulnerability', () {
    final run = BetaSession()..learnSkill(BetaSkill.ward);
    run.start();
    earnPoints(run);
    run.learnSkill(BetaSkill.stoneStep);
    run.resume();
    impact(run, BetaCombo.steam);
    expect(run.protection, 1);
    run.dodge();
    expect(run.protection, 0);
    expect(run.invulnerable, .42);
    advance(run, 1.7);
    run.dodge();
    expect(run.invulnerable, .3);
  });

  test(
    'Sintonia refunds once per action, not per target, capped at 100 MP',
    () {
      final run = BetaSession()..learnSkill(BetaSkill.manaWeave);
      run.start();
      earnPoints(run);
      run.learnSkill(BetaSkill.flow);
      run.resume();
      run.enemies
        ..clear()
        ..addAll([
          BetaEnemy(BetaEnemyKind.guardian, -.5, 3.4)..cooldown = 100,
          BetaEnemy(BetaEnemyKind.guardian, .5, 3.4)..cooldown = 100,
        ]);
      run.mana = 40;
      run.sword();
      advance(run, .17);
      expect(run.mana, closeTo(40 + .17 * 9 + 6, .001));
      expect(run.enemies.every((e) => e.hp == 173), true);
      run.projectiles.add(
        BetaProjectile(
          -.5,
          3.4,
          0,
          -1,
          BetaElement.fire,
          combo: BetaCombo.eruption,
        ),
      );
      final mana = run.mana;
      run.update(.01);
      expect(run.mana, closeTo(mana + .09 + 8, .001));
      expect(run.enemies.every((e) => e.hp < 173), true);
      run.mana = 99;
      impact(run, BetaCombo.steam);
      expect(run.mana, 100);
    },
  );

  test(
    'pause freezes buffs; travel preserves builds; restarting resets them',
    () {
      final run = BetaSession()..learnSkill(BetaSkill.runicBlade);
      run.start();
      impact(run, BetaCombo.steam);
      run.pause();
      advance(run, 1);
      expect(run.runicBladeTime, 4);
      run.enemies.clear();
      run.resume();
      restorePuzzle(run);
      run.x = BetaRegion.gateX;
      run.z = BetaRegion.gateZ;
      advance(run, 2.6);
      expect(run.wave, 2);
      expect(run.runicBladeTime, 0);
      expect(run.hasSkill(BetaSkill.runicBlade), true);
      expect(run.equippedCombos, [BetaCombo.steam]);
      expect(run.discoveredCombos, {BetaCombo.steam});
      expect(run.skillPoints, 0);
      final fresh = BetaSession();
      expect(fresh.skillPoints, 1);
      expect(fresh.hasSkill(BetaSkill.runicBlade), false);
      expect(fresh.equippedCombos, isEmpty);
      expect(fresh.discoveredCombos, isEmpty);
    },
  );
}
