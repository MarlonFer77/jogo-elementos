import 'dart:math';
import 'package:app/game_domain/beta_session.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/beta_puzzle_fixture.dart';

BetaSession duel({BetaEnemyKind kind = BetaEnemyKind.goblin}) {
  final run = BetaSession()..start();
  run.enemies
    ..clear()
    ..add(BetaEnemy(kind, 0, 3.5));
  return run;
}

void advance(BetaSession run, double seconds) {
  for (var remaining = seconds; remaining > .0001; remaining -= 1 / 60) {
    run.update(min(remaining, 1 / 60));
  }
}

void main() {
  test(
    'queued input survives the exact animation boundary at different frame rates',
    () {
      for (final fps in [30, 60, 120]) {
        for (final action in BetaAction.values) {
          final run = duel();
          run.enemies.single.windup = 10;
          if (action == BetaAction.cast) {
            run.sword();
            run.swordTime = BetaSession.inputBuffer;
          } else {
            run.cast();
            run.castTime = BetaSession.inputBuffer;
          }
          expect(run.request(action), true);
          for (var elapsed = 0.0; elapsed < .21; elapsed += 1 / fps) {
            run.update(1 / fps);
          }
          expect(run.queuedAction, isNull);
          expect(
            switch (action) {
              BetaAction.sword => run.swordTime,
              BetaAction.cast => run.castTime,
              BetaAction.dodge => run.dodgeTime,
            },
            greaterThan(0),
            reason: '$action at $fps FPS',
          );
          expect(run.sounds.where((e) => e == BetaSound.cast), hasLength(1));
          expect(run.mana, inInclusiveRange(75, 78));
        }
      }
    },
  );

  test(
    'passage waits for the player, pauses and preserves capped recovery',
    () {
      final run = BetaSession()..start();
      expect(run.nextEncounterIn, 0);
      run.enemies.clear();
      run.hp = 89;
      restorePuzzle(run);
      expect(run.nextEncounterIn, 2);
      advance(run, 1);
      expect(run.nextEncounterIn, closeTo(1, .001));
      run.pause();
      final countdown = run.nextEncounterIn;
      run.update(.1);
      expect(run.nextEncounterIn, countdown);
      run.resume();
      advance(run, 1.05);
      expect(run.wave, 1);
      expect(run.passageOpen, true);
      expect(run.hp, 89);
      advance(run, 4);
      expect(run.wave, 1); // No automatic teleport after winning the encounter.
      run.x = BetaRegion.gateX;
      run.z = BetaRegion.gateZ;
      advance(run, .6);
      expect(run.wave, 2);
      expect(run.region, BetaRegion.aqueduct);
      expect(run.arrivalTime, greaterThan(0));
      expect(run.nextEncounterIn, 0);
      expect(run.hp, 100);
      expect(run.mana, 100);
      advance(run, .4);
      run.wave = BetaRegion.values.length;
      run.enemies.clear();
      restorePuzzle(run);
      advance(run, 2.1);
      run.x = BetaRegion.gateX;
      run.z = BetaRegion.gateZ;
      advance(run, .6);
      expect(run.phase, BetaPhase.won);
      expect(run.nextEncounterIn, 0);
    },
  );

  test(
    'region travel rejects combat and cancels held actions across frame rates',
    () {
      for (final fps in [30, 60, 120]) {
        final run = BetaSession()..start();
        run.x = BetaRegion.gateX;
        run.z = BetaRegion.gateZ;
        advance(run, .6);
        expect(run.wave, 1); // Enemies still alive: passage remains locked.
        run.enemies.clear();
        run.x = 0;
        run.z = 0;
        restorePuzzle(run);
        advance(run, 2.1);
        expect(run.sounds.where((s) => s == BetaSound.passage), hasLength(1));
        run.z = BetaRegion.gateZ;
        advance(run, .3);
        expect(run.passageProgress, greaterThan(0));
        run.pause();
        advance(run, 1);
        expect(run.passageProgress, 0);
        expect(run.wave, 1);
        run.resume();
        run.hp = 60;
        run.mana = 30;
        run.level = 2;
        run.xp = 65;
        run.select(BetaElement.water);
        final kills = run.kills;
        for (var t = 0.0; t < .6; t += 1 / fps) {
          run.update(1 / fps);
        }
        expect(run.wave, 2);
        expect(run.x, BetaRegion.entryX);
        expect(run.z, BetaRegion.entryZ);
        expect(run.hp, 80);
        expect(run.mana, inInclusiveRange(55, 61));
        expect(run.level, 2);
        expect(run.xp, 65);
        expect(run.kills, kills);
        expect(run.element, BetaElement.water);
        expect(run.queuedAction, isNull);
        expect(run.projectiles, isEmpty);
        expect(run.effects, isEmpty);
        expect(run.passageOpen, false);
        expect(run.canRequest(BetaAction.cast), false);
        run.setMovement(1, 1);
        expect(run.moveX, 0);
        expect(run.moveZ, 0);
        run.pause();
        final arrival = run.arrivalTime;
        advance(run, 1);
        expect(run.arrivalTime, arrival);
        run.resume();
        advance(run, .4);
        expect(run.canRequest(BetaAction.sword), true);
      }
    },
  );

  test(
    'all regions share visible collision, clear entry and accessible passage',
    () {
      for (final region in BetaRegion.values) {
        final run = BetaSession()..wave = region.index + 1;
        expect(run.obstacles, same(region.obstacles));
        expect(run.walkable(BetaRegion.entryX, BetaRegion.entryZ, .35), true);
        for (var z = BetaRegion.entryZ; z >= BetaRegion.gateZ; z -= .25) {
          expect(run.walkable(0, z, .35), true, reason: region.title);
        }
        for (final o in run.obstacles) {
          expect(run.walkable(o.x, o.z, .35), false);
          expect(run.clearLine(o.x - 1, o.z, o.x + 1, o.z), false);
        }
        run.start();
        for (final enemy in run.enemies) {
          expect(run.walkable(enemy.x, enemy.z, enemy.radius), true);
          expect(
            BetaSession.distance(run.x, run.z, enemy.x, enemy.z),
            greaterThan(5),
          );
        }
        if (region != BetaRegion.values.last) {
          run.enemies.clear();
          restorePuzzle(run);
          run.setMovement(0, -1);
          for (var i = 0; i < 300 && run.region == region; i++) {
            run.update(1 / 60);
          }
          expect(run.wave, region.index + 2, reason: 'Walk to the next region');
          expect(run.moveZ, 0);
        }
      }
    },
  );

  test('each spell impact emits its own sound, misses do not', () {
    final sounds = [
      BetaSound.fireImpact,
      BetaSound.waterImpact,
      BetaSound.windImpact,
      BetaSound.earthImpact,
    ];
    for (final element in BetaElement.values) {
      final run = duel(kind: BetaEnemyKind.guardian);
      run.enemies.single.windup = 10;
      run.projectiles.add(BetaProjectile(0, 5, 0, -1, element));
      advance(run, .1);
      expect(run.sounds.where(sounds.contains), [sounds[element.index]]);
      run.sounds.clear();
      run.projectiles.add(BetaProjectile(8.3, 5, 1, 0, element));
      advance(run, .1);
      expect(run.sounds.where(sounds.contains), isEmpty);
    }
  });

  test('enemy attack shapes share accurate boundaries and rotate with aim', () {
    const thrust = BetaAttackArea(BetaAttackShape.thrust, 0, 0, 0, 2.4);
    expect(thrust.contains(.4, 2.3), true);
    expect(thrust.contains(.43, 1.5), false);
    expect(thrust.contains(0, -.1), false);
    expect(thrust.contains(0, 2.5), false);
    const turned = BetaAttackArea(BetaAttackShape.thrust, 2, 3, pi / 2, 2.4);
    expect(turned.contains(4, 3.4), true);
    expect(turned.contains(2.4, 5), false);
    const sweep = BetaAttackArea(BetaAttackShape.sweep, 0, 0, 0, 2.7);
    expect(sweep.contains(1.7, 1.7), true);
    expect(sweep.contains(0, -1), false);
    expect(sweep.contains(2.6, .1), false);
    const slam = BetaAttackArea(BetaAttackShape.slam, 1, 2, 0, 2.1);
    expect(slam.contains(1, 4.1), true);
    expect(slam.contains(1, 4.11), false);
    for (final area in [thrust, turned, sweep, slam]) {
      for (final vertex in area.outline) {
        expect(area.contains(vertex.x, vertex.z), true);
      }
    }
  });

  test(
    'threat is committed; sidestep, rear and circle exits evade each enemy',
    () {
      for (final kind in BetaEnemyKind.values) {
        final run = duel(kind: kind);
        final enemy = run.enemies.single..cooldown = 0;
        run.update(.01);
        final area = enemy.attackArea;
        expect(area.contains(run.x, run.z), true);
        run.pause();
        final windup = enemy.windup;
        run.update(.1);
        expect(enemy.windup, windup);
        run.resume();
        switch (kind) {
          case BetaEnemyKind.goblin:
            run.x = .6;
          case BetaEnemyKind.brute:
          case BetaEnemyKind.darkElf:
            run.z = 2.5;
          case BetaEnemyKind.guardian:
            run.x = 2.3;
        }
        expect(identical(enemy.attackArea, area), true);
        expect(area.contains(run.x, run.z), false);
        advance(run, windup + .03);
        expect(run.hp, 100);
        expect(enemy.recovery, greaterThan(0));
        expect(
          run.effects.where((e) => e.area != null).single.area,
          same(area),
        );
        final position = [enemy.x, enemy.z];
        advance(run, enemy.recovery - .01);
        expect([enemy.x, enemy.z], position);
        final inside = duel(kind: kind);
        inside.enemies.single.beginAttack(inside.x, inside.z);
        advance(inside, inside.enemies.single.preparation + .02);
        final burnDamage = kind == BetaEnemyKind.guardian
            ? (3 - inside.burnTime) * 2
            : 0.0;
        expect(inside.hp + burnDamage, closeTo(100 - kind.damage, .0001));
        final hpAfterContact = inside.hp;
        final burnBefore = inside.burnTime;
        advance(inside, inside.enemies.single.recoveryDuration + .05);
        // No second impact; the guardian's burn continues during recovery.
        expect(
          inside.hp,
          closeTo(hpAfterContact - (burnBefore - inside.burnTime) * 2, .0001),
        );
        final dodged = duel(kind: kind);
        final attacker = dodged.enemies.single..beginAttack(dodged.x, dodged.z);
        attacker.windup = .01;
        dodged.dodge();
        dodged.update(.02);
        expect(attacker.attackArea.contains(dodged.x, dodged.z), true);
        expect(
          dodged.hp,
          100,
        ); // Invulnerability works even inside the marked area.
      }
    },
  );

  test(
    'wind interruption removes committed threat and never resolves it later',
    () {
      for (final kind in [BetaEnemyKind.brute, BetaEnemyKind.darkElf]) {
        final run = duel(kind: kind);
        final enemy = run.enemies.single..cooldown = 0;
        run.update(.01);
        final oldArea = enemy.attackArea;
        run.projectiles.add(
          BetaProjectile(run.x, run.z, 0, -1, BetaElement.wind),
        );
        advance(run, .1);
        expect(enemy.windup, 0);
        expect(enemy.recovery, 0);
        expect(run.effects.any((fx) => fx.area != null), false);
        advance(run, .8);
        expect(run.hp, 100);
        expect(run.effects.any((fx) => identical(fx.area, oldArea)), false);
      }
      final killed = duel();
      killed.enemies.single
        ..beginAttack(killed.x, killed.z)
        ..hp = 1;
      killed.sword();
      advance(killed, .8);
      expect(killed.hp, 100);
      expect(killed.enemies.single.windup, 0);
      expect(killed.effects.any((fx) => fx.area != null), false);
    },
  );

  test('movement normalizes diagonals, bounds frames, collides and pauses', () {
    final run = BetaSession()..start();
    run.setMovement(1, 1);
    run.update(.1);
    expect(BetaSession.distance(0, 5, run.x, run.z), closeTo(.41, .001));
    run.pause();
    final position = [run.x, run.z, run.time];
    run.update(60);
    expect([run.x, run.z, run.time], position);
    expect(run.moveX, 0);
    run.resume();
    run.setMovement(double.nan, 1);
    expect(run.moveZ, 0);
    run.update(double.infinity);
    run.update(60);
    expect(run.time - position.last, closeTo(.1, .001));
    run.x = 2.8;
    run.z = 2;
    run.setMovement(1, 0);
    advance(run, .4);
    expect(run.x, lessThanOrEqualTo(3));
    expect(run.walkable(run.x, run.z, .35), true);
    run.x = 8;
    run.z = 5;
    advance(run, .5);
    expect(run.x, lessThanOrEqualTo(BetaSession.arenaX - .35));
  });
  test(
    'sword hits once after windup and cannot bypass cooldown or columns',
    () {
      final run = duel();
      final enemy = run.enemies.single;
      expect(run.sword(), true);
      expect(run.sword(), false);
      run.update(.1);
      expect(enemy.hp, 38);
      run.update(.1);
      expect(enemy.hp, 25);
      run.update(.1);
      expect(enemy.hp, 25);
      advance(run, .3);
      expect(run.canSword, true);
      run.x = 2.9;
      run.z = 2;
      enemy.x = 5.1;
      enemy.z = 2;
      run.angle = pi / 2;
      run.sword();
      advance(run, .2);
      expect(enemy.hp, 25);
    },
  );
  test('spells cost mana once, lock element and water heals only on hit', () {
    final run = duel()..hp = 60;
    run.select(BetaElement.water);
    expect(run.cast(), true);
    expect(run.mana, 75);
    expect(run.cast(), false);
    run.select(BetaElement.fire);
    expect(run.element, BetaElement.water);
    advance(run, .5);
    expect(run.enemies.single.slow, greaterThan(0));
    expect(run.hp, 68);
    run.mana = 24;
    advance(run, .8);
    run.mana = 24;
    expect(run.cast(), false);
    final miss = duel()..hp = 60;
    miss.enemies.single
      ..x = 7
      ..z = -7;
    miss.select(BetaElement.water);
    miss.cast();
    advance(miss, .5);
    expect(miss.hp, 60);
  });
  test('fire burns, wind interrupts and earth grants temporary protection', () {
    final fire = duel(kind: BetaEnemyKind.brute)..cast();
    advance(fire, .5);
    expect(fire.enemies.single.burn, greaterThan(0));
    final hp = fire.enemies.single.hp;
    advance(fire, .2);
    expect(fire.enemies.single.hp, lessThan(hp));
    final wind = duel(kind: BetaEnemyKind.brute);
    wind.select(BetaElement.wind);
    wind.cast();
    wind.enemies.single
      ..windup = 1
      ..aimZ = 5;
    advance(wind, .5);
    expect(wind.enemies.single.windup, 0);
    expect(wind.enemies.single.z, lessThan(3.5));
    final earth = duel();
    earth.select(BetaElement.earth);
    earth.cast();
    advance(earth, .4);
    expect(earth.protection, greaterThan(0));
    advance(earth, 2.1);
    expect(earth.protection, 0);
  });
  test('enemy commits a telegraph; dodge is invulnerable and rate limited', () {
    final run = duel();
    final e = run.enemies.single;
    e.cooldown = 0;
    run.update(.016);
    expect(e.windup, greaterThan(0));
    expect([e.aimX, e.aimZ], [0, 5]);
    run.setMovement(1, 0);
    run.update(.1);
    expect([e.aimX, e.aimZ], [0, 5]);
    e.windup = .04;
    expect(run.dodge(), true);
    expect(run.dodge(), false);
    expect(run.dodgeDirection, closeTo(pi / 2, .00001));
    final beforeDodgeX = run.x;
    run.setMovement(
      -1,
      0,
    ); // Moving the thumb must not redirect an active dodge.
    expect(run.dodgeDirection, closeTo(pi / 2, .00001));
    run.update(.05);
    expect(run.x, greaterThan(beforeDodgeX));
    expect(run.hp, 100);
    run.pause();
    expect(run.sword(), false);
    expect(run.cast(), false);
    expect(run.dodge(), false);
  });
  test('six encounters give session XP once and stop on victory/defeat', () {
    final run = BetaSession()..start();
    var totalHealth = 0.0;
    for (var wave = 1; wave <= BetaRegion.values.length; wave++) {
      expect(run.wave, wave);
      expect(run.enemies, hasLength(3));
      expect(
        run.enemies.where((e) => e.kind == BetaEnemyKind.darkElf),
        hasLength(
          wave == 1
              ? 0
              : wave == 4
              ? 2
              : 1,
        ),
      );
      for (final e in run.enemies) {
        totalHealth += e.maxHp;
        e.x = run.x;
        e.z = run.z - 1;
        e.hp = 1;
      }
      run.sword();
      advance(run, .4);
      restorePuzzle(run);
      run.update(.01);
      advance(run, 2);
      run.x = BetaRegion.gateX;
      run.z = BetaRegion.gateZ;
      advance(run, 1);
    }
    expect(run.phase, BetaPhase.won);
    expect(run.kills, 18);
    expect(totalHealth, 1276);
    expect(run.xp, 680);
    expect(run.level, 9);
    expect(run.skillPoints, 9);
    final xp = run.xp;
    advance(run, 10);
    expect(run.xp, xp);
    final lost = duel()..hp = 1;
    lost.enemies.single
      ..windup = .01
      ..aimX = 0
      ..aimZ = 5;
    lost.update(.02);
    expect(lost.phase, BetaPhase.lost);
    expect(lost.cast(), false);
    expect(lost.sword(), false);
  });
  test(
    'roll preserves range across frame rates and has a vulnerable recovery',
    () {
      for (final fps in [30, 60, 120]) {
        for (final heading in [0.0, pi / 2, pi, -pi / 2]) {
          final run = duel()..angle = heading;
          run.enemies.clear();
          final startX = run.x, startZ = run.z;
          expect(run.dodge(), true);
          expect(run.cast(), false);
          expect(run.sword(), false);
          while (run.dodgeTime > .000001) {
            run.update(1 / fps);
          }
          expect(
            run.x,
            closeTo(startX + sin(heading) * BetaSession.dodgeDistance, .00001),
          );
          expect(
            run.z,
            closeTo(startZ + cos(heading) * BetaSession.dodgeDistance, .00001),
          );
          expect(run.invulnerable, 0);
          expect(run.dodge(), false);
          expect(run.mana, 100);
        }
      }
      final wall = duel()..x = BetaSession.arenaX - .35;
      wall.setMovement(1, 0);
      wall.dodge();
      advance(wall, .16);
      wall.pause();
      final remaining = wall.dodgeTime;
      wall.update(.1);
      expect(wall.dodgeTime, remaining);
      wall.resume();
      advance(wall, .16);
      expect(wall.x, BetaSession.arenaX - .35);
      expect(wall.dodgeTime, greaterThan(0));
      expect(wall.invulnerable, 0);
      wall.enemies.single
        ..x = wall.x - 1
        ..z = wall.z
        ..beginAttack(wall.x, wall.z)
        ..windup = .01;
      wall.update(.02);
      expect(wall.hp, 88); // A roll against a wall does not extend immunity.
    },
  );
  test('pursuit goes around a column instead of remaining stuck', () {
    final run = duel()
      ..x = 4
      ..z = 4;
    run.enemies.single
      ..x = 4
      ..z = 0;
    advance(run, 5);
    expect(run.enemies.single.z, greaterThan(3));
  });

  test(
    'body collision stops walking, but never traps an overlapping spawn',
    () {
      final run = duel();
      final enemy = run.enemies.single..cooldown = 10;
      run.setMovement(0, -1);
      advance(run, .7);
      expect(
        BetaSession.distance(run.x, run.z, enemy.x, enemy.z),
        greaterThanOrEqualTo(.35 + enemy.radius - .00001),
      );
      run.x = BetaSession.arenaX - .35;
      run.z = 5;
      run.setMovement(1, 0);
      final stride = run.stride;
      advance(run, .2);
      expect(run.moving, false);
      expect(run.stride, stride);
      enemy
        ..x = run.x
        ..z = run.z;
      run.setMovement(-1, 0);
      run.update(.1);
      expect(run.x, lessThan(BetaSession.arenaX - .35));
    },
  );

  test(
    'buffer executes once, rechecks mana and clears when paused or dodging',
    () {
      final run = duel()..sword();
      advance(run, .4);
      expect(run.request(BetaAction.sword), true);
      advance(run, .16);
      expect(run.queuedAction, isNull);
      expect(run.swordTime, greaterThan(.3));
      advance(run, .7);
      expect(run.swordTime, 0); // A held input is not automatic fire.
      run.spellCooldown = .1;
      expect(run.request(BetaAction.cast), true);
      run.mana = 0;
      advance(run, .15);
      expect(run.castTime, 0);
      expect(run.queuedAction, isNull);
      run.swordCooldown = .1;
      run.request(BetaAction.sword);
      run.pause();
      run.resume();
      advance(run, .2);
      expect(run.swordTime, 0);
      run.swordCooldown = .1;
      run.request(BetaAction.sword);
      run.invulnerable = .5;
      run.dodge();
      expect(run.queuedAction, isNull);
      expect(
        run.invulnerable,
        .5,
      ); // Dodge must not shorten existing protection.
    },
  );

  test('enemy stays committed through impact and recovery before pursuing', () {
    final run = duel();
    final enemy = run.enemies.single
      ..windup = .01
      ..aimX = run.x
      ..aimZ = run.z;
    run.update(.02);
    expect(run.hp, 88);
    expect(enemy.recovery, greaterThan(0));
    final position = [enemy.x, enemy.z];
    run.setMovement(1, 0);
    advance(run, .2);
    expect([enemy.x, enemy.z], position);
    advance(run, .3);
    expect(enemy.recovery, 0);
    expect(enemy.moving, true);
  });

  test('wind displacement is continuous and stops before columns', () {
    final run = duel();
    final enemy = run.enemies.single
      ..x = 2.8
      ..z = 2
      ..pushTime = .2
      ..pushX = 6
      ..pushZ = 0;
    run.update(.01);
    expect(enemy.x, closeTo(2.86, .0001));
    advance(run, .21);
    expect(run.walkable(enemy.x, enemy.z, enemy.radius), true);
    expect(enemy.x, lessThan(3));
    expect(enemy.pushTime, 0);
  });

  test(
    'enemy fades before final exit, with no duplicate damage or rewards',
    () {
      final run = duel()..wave = BetaRegion.values.length;
      restorePuzzle(run);
      final enemy = run.enemies.single..hp = 1;
      run.sword();
      advance(run, .2);
      expect(run.phase, BetaPhase.playing);
      expect(enemy.deathTime, greaterThan(0));
      final hp = run.hp, xp = run.xp;
      advance(run, 1);
      expect(run.settling, false);
      expect(enemy.deathTime, 0);
      expect(run.hp, hp);
      expect(run.xp, xp);
      expect(run.kills, 1);
      advance(run, 2);
      run.x = BetaRegion.gateX;
      run.z = BetaRegion.gateZ;
      advance(run, .6);
      expect(run.phase, BetaPhase.won);
      expect(run.settling, true);
      expect(run.request(BetaAction.cast), false);
      advance(run, 1);
      expect(run.settling, false);
      expect(run.hp, hp);
      expect(run.xp, xp);
    },
  );

  test(
    'aim respects facing and joystick, then stays committed during a cast',
    () {
      final run = duel();
      final front = run.enemies.single..z = 2;
      final behind = BetaEnemy(BetaEnemyKind.goblin, 0, 6);
      run.enemies.add(behind);
      expect(run.aimTarget, same(front));
      expect(run.inSwordRange(front), false);
      run.setMovement(0, 1);
      expect(
        run.aimTarget,
        same(behind),
      ); // No update needed before touching Cast.
      expect(run.inSwordRange(behind), true);
      run.cast();
      run.setMovement(0, -1);
      run.update(.1);
      expect(run.aimTarget, same(behind));
      expect(run.angle, closeTo(0, .00001));
      behind.hp = 0;
      expect(
        run.aimTarget,
        isNull,
      ); // Never silently switches targets mid-spell.
      advance(run, .3);
      expect(run.projectiles.single.dz, closeTo(1, .00001));
      expect(front.hp, front.maxHp);
    },
  );

  test(
    'swept projectile hits the first body, independent of enemy list order',
    () {
      final run = duel();
      final far = run.enemies.single
        ..z = 3.95
        ..windup = 10;
      final near = BetaEnemy(BetaEnemyKind.goblin, 0, 3.99)..windup = 10;
      run.enemies.add(near);
      run.projectiles.add(BetaProjectile(0, 5, 0, -1, BetaElement.fire));
      run.update(.05);
      expect(far.hp, far.maxHp);
      expect(near.hp, lessThan(near.maxHp));
      expect(run.projectiles, isEmpty);
      expect(run.effects.single.kind, BetaEffectKind.spell);
    },
  );

  test(
    'wind shows one blast centered on contact, with secondary hit feedback',
    () {
      final run = duel();
      final primary = run.enemies.single..windup = 10;
      final secondary = BetaEnemy(BetaEnemyKind.goblin, 1.4, 3.5)..windup = 10;
      run.enemies.add(secondary);
      run.projectiles.add(BetaProjectile(0, 5, 0, -1, BetaElement.wind));
      advance(run, .1);
      final blast = run.effects
          .where((e) => e.kind == BetaEffectKind.spell)
          .single;
      expect(blast.z, closeTo(3.5 + primary.radius + .35, .0001));
      expect(secondary.hp, secondary.maxHp - 10);
      expect(
        run.effects.where((e) => e.kind == BetaEffectKind.impact),
        hasLength(1),
      );
    },
  );

  test('column blocks aim and projectile before a creature behind it', () {
    final run = duel()
      ..x = 2
      ..z = 2
      ..angle = pi / 2;
    final enemy = run.enemies.single
      ..x = 5.2
      ..z = 2
      ..windup = 10;
    expect(run.aimTarget, isNull);
    run.projectiles.add(BetaProjectile(3.15, 2, 1, 0, BetaElement.water));
    run.update(.1);
    expect(enemy.hp, enemy.maxHp);
    expect(run.projectiles, isEmpty);
    expect(run.effects.single.kind, BetaEffectKind.blocked);
    expect(
      run.effects.single.x,
      closeTo(4 - .65 - BetaSession.projectileRadius, .0001),
    );
    // Boundary impacts are treated consistently with columns.
    run.effects.clear();
    run.projectiles.add(BetaProjectile(8.3, 5, 1, 0, BetaElement.fire));
    run.update(.1);
    expect(run.projectiles, isEmpty);
    expect(
      run.effects.single.x,
      closeTo(BetaSession.arenaX - BetaSession.projectileRadius, .0001),
    );
  });

  test(
    'water feedback reports actual healing, never overheal or healing on walls',
    () {
      final run = duel()..hp = 97;
      run.enemies.single.windup = 10;
      run.projectiles.add(BetaProjectile(0, 5, 0, -1, BetaElement.water));
      advance(run, .1);
      expect(run.hp, 100);
      expect(
        run.effects.where((e) => e.kind == BetaEffectKind.heal).single.text,
        '+3',
      );
      run.effects.clear();
      run.projectiles.add(BetaProjectile(0, 5, 0, -1, BetaElement.water));
      advance(run, .1);
      expect(run.effects.where((e) => e.kind == BetaEffectKind.heal), isEmpty);
      run.hp = 50;
      run.projectiles.add(BetaProjectile(3.15, 2, 1, 0, BetaElement.water));
      advance(run, .1);
      expect(run.hp, 50);
    },
  );
}
