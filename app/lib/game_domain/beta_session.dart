import 'dart:math' as math;

/// Offline sandbox. Never writes campaign/online rewards or turn-based saves.
enum BetaPhase { ready, playing, paused, won, lost }

enum BetaElement {
  fire('Fogo', 'Projétil + queimadura'),
  water('Água', 'Lentidão + cura ao acertar'),
  wind('Vento', 'Explosão que afasta inimigos'),
  earth('Terra', 'Impacto + proteção por 2s');

  const BetaElement(this.label, this.description);
  final String label, description;
}

enum BetaEnemyKind { goblin, brute, guardian }

enum BetaSound { sword, cast, impact, hurt, dodge, level, victory, defeat }

class BetaObstacle {
  const BetaObstacle(this.x, this.z, this.radius, this.height);
  final double x, z, radius, height;
}

class BetaEnemy {
  BetaEnemy(this.kind, this.x, this.z)
    : hp = switch (kind) {
        BetaEnemyKind.goblin => 38,
        BetaEnemyKind.brute => 72,
        BetaEnemyKind.guardian => 190,
      };
  final BetaEnemyKind kind;
  double x, z, hp;
  double angle = 0, windup = 0, cooldown = .6, aimX = 0, aimZ = 0;
  double slow = 0, burn = 0, flash = 0, stride = 0;
  double detour = 0, steerX = 0, steerZ = 0;
  bool moving = false;
  bool get alive => hp > 0;
  bool get boss => kind == BetaEnemyKind.guardian;
  double get radius => boss ? .75 : .42;
  double get maxHp => switch (kind) {
    BetaEnemyKind.goblin => 38,
    BetaEnemyKind.brute => 72,
    BetaEnemyKind.guardian => 190,
  };
  double get attackRadius => boss
      ? 2.1
      : kind == BetaEnemyKind.brute
      ? 1.25
      : .95;
  double get preparation => boss ? 1.05 : .7;
}

class BetaProjectile {
  BetaProjectile(this.x, this.z, this.dx, this.dz, this.element);
  double x, z, life = 1.3;
  final double dx, dz;
  final BetaElement element;
}

class BetaEffect {
  BetaEffect(this.x, this.z, this.element, {this.text, this.hurt = false});
  final double x, z;
  final BetaElement element;
  final String? text;
  final bool hurt;
  double life = .65;
}

class BetaSession {
  static const arenaX = 8.5, arenaZ = 10.5;
  static const obstacles = [
    BetaObstacle(-4, 2, .65, 2.7),
    BetaObstacle(4, 2, .65, 2.7),
    BetaObstacle(-4, -5, .65, 1.5),
    BetaObstacle(4, -5, .65, 3.1),
  ];
  BetaPhase phase = BetaPhase.ready;
  BetaElement element = BetaElement.fire;
  final enemies = <BetaEnemy>[];
  final projectiles = <BetaProjectile>[];
  final effects = <BetaEffect>[];
  final sounds = <BetaSound>[];
  double x = 0, z = 5, angle = math.pi, hp = 100, mana = 100, time = 0;
  double moveX = 0,
      moveZ = 0,
      swordCooldown = 0,
      spellCooldown = 0,
      dodgeCooldown = 0;
  double swordTime = 0,
      castTime = 0,
      dodgeTime = 0,
      invulnerable = 0,
      protection = 0;
  double _dodgeX = 0, _dodgeZ = 0, _waveWait = 0;
  bool _swordPending = false;
  BetaElement _castElement = BetaElement.fire;
  int wave = 1, level = 1, xp = 0, kills = 0;
  String message = 'Explore a ruína. Derrote o guardião.';
  double messageTime = 5;
  double get maxHp => 100 + (level - 1) * 10;
  int get nextLevelXp => 60 + (level - 1) * 80;
  bool get playing => phase == BetaPhase.playing;
  bool get moving =>
      playing && (moveX.abs() + moveZ.abs() > .05 || dodgeTime > 0);
  int get remaining => enemies.where((e) => e.alive).length;
  bool get canSword =>
      playing && swordCooldown <= 0 && castTime <= 0 && dodgeTime <= 0;
  bool get canCast =>
      playing &&
      spellCooldown <= 0 &&
      mana >= 25 &&
      swordTime <= 0 &&
      dodgeTime <= 0;
  bool get canDodge => playing && dodgeCooldown <= 0 && castTime <= 0;

  void start() {
    if (phase != BetaPhase.ready) return;
    phase = BetaPhase.playing;
    _spawn();
  }

  void pause() {
    if (playing) phase = BetaPhase.paused;
    setMovement(0, 0);
  }

  void resume() {
    if (phase == BetaPhase.paused) phase = BetaPhase.playing;
  }

  void setMovement(double horizontal, double vertical) {
    if (!horizontal.isFinite || !vertical.isFinite || !playing) {
      moveX = moveZ = 0;
      return;
    }
    final length = math.sqrt(horizontal * horizontal + vertical * vertical);
    final scale = math.max(1, length);
    moveX = horizontal / scale;
    moveZ = vertical / scale;
  }

  void select(BetaElement value) {
    if (playing && castTime <= 0 && swordTime <= 0) element = value;
  }

  bool sword() {
    if (!canSword) return false;
    _aim(2.8);
    swordCooldown = .52;
    swordTime = .32;
    _swordPending = true;
    sounds.add(BetaSound.sword);
    return true;
  }

  bool cast() {
    if (!canCast) return false;
    _aim(9);
    _castElement = element;
    mana -= 25;
    castTime = .35;
    spellCooldown = 1.25;
    sounds.add(BetaSound.cast);
    return true;
  }

  bool dodge() {
    if (!canDodge) return false;
    final length = math.sqrt(moveX * moveX + moveZ * moveZ);
    _dodgeX = length > .05 ? moveX / length : math.sin(angle);
    _dodgeZ = length > .05 ? moveZ / length : math.cos(angle);
    dodgeTime = .24;
    invulnerable = .3;
    dodgeCooldown = 1.6;
    swordTime = 0;
    _swordPending = false;
    sounds.add(BetaSound.dodge);
    return true;
  }

  void _aim(double range) {
    BetaEnemy? nearest;
    for (final e in enemies.where((e) => e.alive)) {
      final d = distance(x, z, e.x, e.z);
      if (d < range && clearLine(x, z, e.x, e.z)) {
        range = d;
        nearest = e;
      }
    }
    if (nearest != null) angle = math.atan2(nearest.x - x, nearest.z - z);
  }

  static double distance(double ax, double az, double bx, double bz) =>
      math.sqrt((ax - bx) * (ax - bx) + (az - bz) * (az - bz));
  static bool walkable(double px, double pz, double radius) =>
      px.abs() <= arenaX - radius &&
      pz.abs() <= arenaZ - radius &&
      obstacles.every((o) => distance(px, pz, o.x, o.z) >= radius + o.radius);
  static bool clearLine(double ax, double az, double bx, double bz) {
    final dx = bx - ax, dz = bz - az, length = dx * dx + dz * dz;
    return obstacles.every((o) {
      final t = length == 0
          ? 0.0
          : (((o.x - ax) * dx + (o.z - az) * dz) / length).clamp(0.0, 1.0);
      return distance(ax + dx * t, az + dz * t, o.x, o.z) > o.radius + .1;
    });
  }

  void _move(double dx, double dz) {
    final nx = (x + dx).clamp(-arenaX + .35, arenaX - .35);
    final nz = (z + dz).clamp(-arenaZ + .35, arenaZ - .35);
    if (walkable(nx, z, .35)) x = nx;
    if (walkable(x, nz, .35)) z = nz;
  }

  static double _tick(double timer, double dt) => math.max(0, timer - dt);

  /// Bounded substeps: resuming a suspended app never applies a huge time jump.
  void update(double elapsed) {
    if (!playing || !elapsed.isFinite || elapsed <= 0) return;
    var left = math.min(elapsed, .1);
    while (left > .000001 && playing) {
      final dt = math.min(left, 1 / 60);
      _step(dt);
      left -= dt;
    }
  }

  void _step(double dt) {
    time += dt;
    messageTime = _tick(messageTime, dt);
    swordCooldown = _tick(swordCooldown, dt);
    spellCooldown = _tick(spellCooldown, dt);
    dodgeCooldown = _tick(dodgeCooldown, dt);
    invulnerable = _tick(invulnerable, dt);
    protection = _tick(protection, dt);
    mana = math.min(100, mana + dt * 9);
    final speed = dodgeTime > 0
        ? 11.0
        : castTime > 0
        ? 1.1
        : swordTime > 0
        ? 2.0
        : 4.1;
    _move(
      (dodgeTime > 0 ? _dodgeX : moveX) * speed * dt,
      (dodgeTime > 0 ? _dodgeZ : moveZ) * speed * dt,
    );
    if (moving && swordTime <= 0 && castTime <= 0 && dodgeTime <= 0) {
      angle = math.atan2(moveX, moveZ);
    }
    dodgeTime = _tick(dodgeTime, dt);
    swordTime = _tick(swordTime, dt);
    if (_swordPending && swordTime <= .18) {
      _swordPending = false;
      for (final e in enemies.where((e) => e.alive)) {
        final dx = e.x - x, dz = e.z - z, d = distance(x, z, e.x, e.z);
        if (d <= 1.9 + e.radius &&
            (d < .1 ||
                (dx * math.sin(angle) + dz * math.cos(angle)) / d > .15) &&
            clearLine(x, z, e.x, e.z)) {
          _hit(e, 13 + (level - 1) * 2.0, element);
        }
      }
    }
    if (castTime > 0) {
      castTime = _tick(castTime, dt);
      if (castTime == 0) {
        projectiles.add(
          BetaProjectile(x, z, math.sin(angle), math.cos(angle), _castElement),
        );
        if (_castElement == BetaElement.earth) protection = 2;
      }
    }
    for (final p in projectiles) {
      final nx = p.x + p.dx * dt * 12, nz = p.z + p.dz * dt * 12;
      p.life -= dt;
      if (!walkable(nx, nz, .12) || !clearLine(p.x, p.z, nx, nz)) p.life = 0;
      p.x = nx;
      p.z = nz;
      if (p.life <= 0) continue;
      for (final e in enemies.where((e) => e.alive)) {
        if (distance(p.x, p.z, e.x, e.z) > e.radius + .35) continue;
        final damage = switch (p.element) {
          BetaElement.fire => 27.0,
          BetaElement.water => 18.0,
          BetaElement.wind => 16.0,
          BetaElement.earth => 23.0,
        };
        _hit(e, damage + (level - 1) * 3, p.element);
        if (p.element == BetaElement.fire && e.alive) e.burn = 3;
        if (p.element == BetaElement.water) {
          e.slow = 2.5;
          hp = math.min(maxHp, hp + 8);
        }
        if (p.element == BetaElement.wind) {
          for (final target in enemies.where((e) => e.alive)) {
            if (distance(p.x, p.z, target.x, target.z) < 2 &&
                clearLine(p.x, p.z, target.x, target.z)) {
              if (!identical(target, e)) _hit(target, 10, p.element);
              target.windup = 0;
              target.cooldown = .8;
              final tx = target.x + p.dx * 1.2, tz = target.z + p.dz * 1.2;
              if (walkable(tx, tz, target.radius) &&
                  clearLine(target.x, target.z, tx, tz)) {
                target.x = tx;
                target.z = tz;
              }
            }
          }
        }
        p.life = 0;
        break;
      }
    }
    projectiles.removeWhere((p) => p.life <= 0);
    for (final e in enemies.where((e) => e.alive)) {
      if (!playing) break;
      e.flash = _tick(e.flash, dt);
      e.slow = _tick(e.slow, dt);
      if (e.burn > 0) {
        e.burn = _tick(e.burn, dt);
        e.hp = math.max(0, e.hp - 3 * dt);
        if (!e.alive) {
          _kill(e);
          continue;
        }
      }
      e.moving = false;
      if (e.windup > 0) {
        e.windup = _tick(e.windup, dt);
        if (e.windup == 0) {
          e.cooldown = e.boss ? 1.7 : 1.3;
          effects.add(
            BetaEffect(e.aimX, e.aimZ, BetaElement.earth, hurt: true),
          );
          if (distance(x, z, e.aimX, e.aimZ) < e.attackRadius &&
              clearLine(e.x, e.z, x, z)) {
            _hurt(e.boss ? 25 : 12);
          }
        }
        continue;
      }
      e.cooldown = _tick(e.cooldown, dt);
      final dx = x - e.x, dz = z - e.z, d = distance(x, z, e.x, e.z);
      e.angle = math.atan2(dx, dz);
      if (d < (e.boss ? 2.6 : 1.55) &&
          e.cooldown == 0 &&
          clearLine(e.x, e.z, x, z)) {
        e.windup = e.preparation;
        e.aimX = x;
        e.aimZ = z;
      } else if (d > .95) {
        final speed =
            (e.boss
                ? 1.35
                : e.kind == BetaEnemyKind.brute
                ? 1.65
                : 2.15) *
            (e.slow > 0 ? .45 : 1);
        var headingX = dx / d, headingZ = dz / d;
        if (e.detour <= 0 &&
            !walkable(
              e.x + headingX * speed * dt,
              e.z + headingZ * speed * dt,
              e.radius,
            )) {
          // Briefly commit to a side instead of oscillating against a column.
          for (final side in [1.0, -1.0]) {
            final sx = -headingZ * side, sz = headingX * side;
            if (walkable(e.x + sx * .3, e.z + sz * .3, e.radius)) {
              e.steerX = sx;
              e.steerZ = sz;
              e.detour = 1.1;
              break;
            }
          }
        }
        if (e.detour > 0) {
          e.detour = _tick(e.detour, dt);
          headingX = e.steerX;
          headingZ = e.steerZ;
        }
        final nx = e.x + headingX * speed * dt,
            nz = e.z + headingZ * speed * dt;
        bool free(double px, double pz) =>
            walkable(px, pz, e.radius) &&
            enemies.every(
              (other) =>
                  identical(e, other) ||
                  !other.alive ||
                  distance(px, pz, other.x, other.z) >
                      (e.radius + other.radius) * .8,
            );
        if ((nx - e.x).abs() > .00001 && free(nx, e.z)) {
          e.x = nx;
          e.moving = true;
        }
        if ((nz - e.z).abs() > .00001 && free(e.x, nz)) {
          e.z = nz;
          e.moving = true;
        }
        if (e.moving) e.stride += dt * 8;
      }
    }
    for (final fx in effects) {
      fx.life -= dt;
    }
    effects.removeWhere((fx) => fx.life <= 0);
    if (effects.length > 40) effects.removeRange(0, effects.length - 40);
    if (!playing) return;
    if (remaining == 0) {
      if (wave == 3) {
        phase = BetaPhase.won;
        setMovement(0, 0);
        sounds.add(BetaSound.victory);
      } else {
        _waveWait += dt;
        if (_waveWait >= 2) {
          wave++;
          _waveWait = 0;
          hp = math.min(maxHp, hp + 20);
          mana = math.min(100, mana + 25);
          _spawn();
        }
      }
    }
  }

  void _hit(BetaEnemy e, double damage, BetaElement source) {
    if (!e.alive) return;
    e.hp = math.max(0, e.hp - damage);
    e.flash = .15;
    effects.add(BetaEffect(e.x, e.z, source, text: '${damage.round()}'));
    sounds.add(BetaSound.impact);
    if (!e.alive) _kill(e);
  }

  void _kill(BetaEnemy e) {
    kills++;
    xp += e.boss
        ? 100
        : e.kind == BetaEnemyKind.brute
        ? 40
        : 20;
    while (xp >= nextLevelXp) {
      level++;
      hp = math.min(maxHp, hp + 20);
      message = 'NÍVEL $level · vitalidade e dano aumentaram';
      messageTime = 3;
      sounds.add(BetaSound.level);
    }
  }

  void _hurt(double amount) {
    if (!playing || invulnerable > 0) return;
    final damage = protection > 0 ? amount * .5 : amount;
    hp = math.max(0, hp - damage);
    invulnerable = .5;
    effects.add(
      BetaEffect(x, z, element, text: '-${damage.round()}', hurt: true),
    );
    sounds.add(BetaSound.hurt);
    if (hp == 0) {
      phase = BetaPhase.lost;
      setMovement(0, 0);
      sounds.add(BetaSound.defeat);
    }
  }

  void _spawn() {
    enemies.clear();
    projectiles.clear();
    final kinds = switch (wave) {
      1 => [BetaEnemyKind.goblin, BetaEnemyKind.goblin, BetaEnemyKind.goblin],
      2 => [BetaEnemyKind.goblin, BetaEnemyKind.brute, BetaEnemyKind.goblin],
      _ => [BetaEnemyKind.goblin, BetaEnemyKind.guardian, BetaEnemyKind.goblin],
    };
    for (var i = 0; i < kinds.length; i++) {
      // Spawn at the far end from the hero; never on a column or on the player.
      enemies.add(BetaEnemy(kinds[i], (i - 1) * 3.0, z >= 0 ? -7 : 7));
    }
    message = wave == 3
        ? 'GUARDIÃO · saia dos círculos antes do impacto'
        : 'ENCONTRO $wave/3 · derrote os goblins';
    messageTime = 4;
  }
}
