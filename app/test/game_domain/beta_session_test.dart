import 'dart:math';
import 'package:app/game_domain/beta_session.dart';
import 'package:flutter_test/flutter_test.dart';

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
    expect(BetaSession.walkable(run.x, run.z, .35), true);
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
    run.update(.05);
    expect(run.hp, 100);
    run.pause();
    expect(run.sword(), false);
    expect(run.cast(), false);
    expect(run.dodge(), false);
  });
  test('three encounters give session XP once and stop on victory/defeat', () {
    final run = BetaSession()..start();
    for (var wave = 1; wave <= 3; wave++) {
      expect(run.wave, wave);
      for (final e in run.enemies) {
        e.x = run.x;
        e.z = run.z - 1;
        e.hp = 1;
      }
      run.sword();
      advance(run, .4);
      if (wave < 3) advance(run, 2);
    }
    expect(run.phase, BetaPhase.won);
    expect(run.kills, 9);
    expect(run.level, greaterThan(1));
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
}
