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

enum BetaSound {
  sword,
  cast,
  impact,
  hurt,
  dodge,
  level,
  victory,
  defeat,
  enemySwing,
  heavyImpact,
  fireImpact,
  waterImpact,
  windImpact,
  earthImpact,
}

enum BetaAction { sword, cast, dodge }

enum BetaEffectKind { impact, spell, blocked, heal }

enum BetaAttackShape { thrust, sweep, slam }

/// Immutable attack commitment, shared by hit detection and presentation.
/// Dimensions are world units; contains checks the player's ground position.
class BetaAttackArea {
  const BetaAttackArea(this.shape, this.x, this.z, this.angle, this.reach);
  final BetaAttackShape shape;
  final double x, z, angle, reach;
  static const thrustHalfWidth = .42, sweepHalfAngle = math.pi * .38;

  bool contains(double px, double pz) {
    final dx = px - x, dz = pz - z;
    final forward = dx * math.sin(angle) + dz * math.cos(angle);
    final side = dx * math.cos(angle) - dz * math.sin(angle);
    const epsilon = .000001;
    return switch (shape) {
      BetaAttackShape.thrust =>
        forward >= -epsilon &&
            forward <= reach + epsilon &&
            side.abs() <= thrustHalfWidth + epsilon,
      BetaAttackShape.sweep =>
        dx * dx + dz * dz <= reach * reach + epsilon &&
            (dx.abs() + dz.abs() < epsilon ||
                forward >=
                    math.sqrt(dx * dx + dz * dz) * math.cos(sweepHalfAngle) -
                        epsilon),
      BetaAttackShape.slam => dx * dx + dz * dz <= reach * reach + epsilon,
    };
  }

  List<({double x, double z})> get outline {
    ({double x, double z}) point(double forward, double side) => (
      x: x + forward * math.sin(angle) + side * math.cos(angle),
      z: z + forward * math.cos(angle) - side * math.sin(angle),
    );
    if (shape == BetaAttackShape.thrust) {
      return [
        point(0, -thrustHalfWidth),
        point(reach, -thrustHalfWidth),
        point(reach, thrustHalfWidth),
        point(0, thrustHalfWidth),
      ];
    }
    final halfAngle = shape == BetaAttackShape.slam ? math.pi : sweepHalfAngle;
    return [
      if (shape == BetaAttackShape.sweep) (x: x, z: z),
      for (var i = 0; i <= 24; i++)
        point(
          math.cos(-halfAngle + i * halfAngle / 12) * reach,
          math.sin(-halfAngle + i * halfAngle / 12) * reach,
        ),
    ];
  }
}

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
  double recovery = 0, deathTime = 0, pushTime = 0, pushX = 0, pushZ = 0;
  bool _rewarded = false;
  BetaAttackArea? _attackArea;
  bool moving = false;
  bool get alive => hp > 0;
  bool get boss => kind == BetaEnemyKind.guardian;
  String get label => switch (kind) {
    BetaEnemyKind.goblin => 'Goblin',
    BetaEnemyKind.brute => 'Bruto',
    BetaEnemyKind.guardian => 'Guardião',
  };
  double get radius => boss ? .75 : .42;
  double get maxHp => switch (kind) {
    BetaEnemyKind.goblin => 38,
    BetaEnemyKind.brute => 72,
    BetaEnemyKind.guardian => 190,
  };
  BetaAttackShape get attackShape => switch (kind) {
    BetaEnemyKind.goblin => BetaAttackShape.thrust,
    BetaEnemyKind.brute => BetaAttackShape.sweep,
    BetaEnemyKind.guardian => BetaAttackShape.slam,
  };
  String get attackLabel => switch (attackShape) {
    BetaAttackShape.thrust => 'Estocada',
    BetaAttackShape.sweep => 'Varredura',
    BetaAttackShape.slam => 'Impacto',
  };
  double get preparation => switch (kind) {
    BetaEnemyKind.goblin => .7,
    BetaEnemyKind.brute => .85,
    BetaEnemyKind.guardian => 1.05,
  };
  double get recoveryDuration => switch (kind) {
    BetaEnemyKind.goblin => .36,
    BetaEnemyKind.brute => .55,
    BetaEnemyKind.guardian => .75,
  };
  double get strikeDuration => kind == BetaEnemyKind.goblin ? .12 : .18;
  BetaAttackArea get attackArea => _attackArea ?? _makeArea();

  BetaAttackArea _makeArea() => BetaAttackArea(
    attackShape,
    boss ? aimX : x,
    boss ? aimZ : z,
    math.atan2(aimX - x, aimZ - z),
    boss
        ? 2.1
        : kind == BetaEnemyKind.brute
        ? 2.7
        : 2.4,
  );

  void beginAttack(double targetX, double targetZ) {
    aimX = targetX;
    aimZ = targetZ;
    angle = math.atan2(aimX - x, aimZ - z);
    _attackArea = _makeArea();
    windup = preparation;
    recovery = 0;
  }

  void cancelAttack() {
    windup = recovery = 0;
    _attackArea = null;
  }
}

class BetaProjectile {
  BetaProjectile(this.x, this.z, this.dx, this.dz, this.element);
  double x, z, life = 1.3;
  final double dx, dz;
  final BetaElement element;
}

class BetaEffect {
  BetaEffect(
    this.x,
    this.z,
    this.element, {
    this.text,
    this.hurt = false,
    this.kind = BetaEffectKind.impact,
    this.area,
  });
  final double x, z;
  final BetaElement element;
  final String? text;
  final bool hurt;
  final BetaEffectKind kind;
  final BetaAttackArea? area;
  double life = .65;
}

class BetaSession {
  static const arenaX = 8.5, arenaZ = 10.5;
  // Shared with the renderer: the blade crosses its target at swordContact.
  static const swordDuration = .44, swordContact = .16, castDuration = .35;
  static const deathDuration = .65, inputBuffer = .18;
  static const swordReach = 1.9, spellAimRange = 9.0, projectileRadius = .12;
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
  double stride = 0, hurtTime = 0, impactTime = 0, resultTime = 0;
  double _bufferTime = 0;
  bool _moving = false;
  int swordSide = 1;
  BetaAction? queuedAction;
  bool _swordPending = false;
  BetaElement _castElement = BetaElement.fire;
  BetaEnemy? _actionTarget;
  int wave = 1, level = 1, xp = 0, kills = 0;
  String message = 'Explore a ruína. Derrote o guardião.';
  double messageTime = 5;
  double get maxHp => 100 + (level - 1) * 10;
  int get nextLevelXp => 60 + (level - 1) * 80;
  bool get playing => phase == BetaPhase.playing;
  bool get moving => playing && _moving;
  bool get settling => resultTime > 0;
  double get nextEncounterIn =>
      (playing || phase == BetaPhase.paused) && wave < 3 && remaining == 0
      ? math.max(0, 2 - _waveWait)
      : 0;
  bool get canSelectElement => playing && castTime <= 0 && swordTime <= 0;
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
  double get aimDirection => swordTime > 0 || castTime > 0 ? angle : _aimAngle;
  BetaEnemy? get aimTarget {
    if (!playing) return null;
    if (swordTime > 0 || castTime > 0) {
      return _actionTarget?.alive == true ? _actionTarget : null;
    }
    return _findTarget(spellAimRange);
  }

  bool inSwordRange(BetaEnemy target) =>
      target.alive &&
      distance(x, z, target.x, target.z) <= swordReach + target.radius &&
      clearLine(x, z, target.x, target.z);

  void start() {
    if (phase != BetaPhase.ready) return;
    phase = BetaPhase.playing;
    _spawn();
  }

  void pause() {
    if (playing) phase = BetaPhase.paused;
    // Backgrounding during the result transition must not hide every control
    // behind a stopped game loop. Reveal the result immediately in that case.
    if (phase == BetaPhase.won || phase == BetaPhase.lost) resultTime = 0;
    setMovement(0, 0);
    _clearBuffer();
    _moving = false;
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
    if (canSelectElement) {
      element = value;
      _clearBuffer();
    }
  }

  double _actionWait(BetaAction action) => switch (action) {
    BetaAction.sword => math.max(swordCooldown, math.max(castTime, dodgeTime)),
    BetaAction.cast => math.max(spellCooldown, math.max(swordTime, dodgeTime)),
    BetaAction.dodge => math.max(dodgeCooldown, castTime),
  };

  bool canRequest(BetaAction action) =>
      playing &&
      (action != BetaAction.cast || mana >= 25) &&
      _actionWait(action) <= inputBuffer;

  /// One short-lived intent, never a chain of automatic attacks. Revalidated
  /// on execution and discarded on pause, element change or dodge.
  bool request(BetaAction action) {
    if (!canRequest(action)) return false;
    if (_actionWait(action) <= 0) {
      _clearBuffer();
      return _execute(action);
    }
    queuedAction = action;
    _bufferTime = inputBuffer;
    return true;
  }

  bool _execute(BetaAction action) => switch (action) {
    BetaAction.sword => sword(),
    BetaAction.cast => cast(),
    BetaAction.dodge => dodge(),
  };

  void _clearBuffer() {
    queuedAction = null;
    _bufferTime = 0;
  }

  void _consumeInput(double dt) {
    final action = queuedAction;
    if (action == null) return;
    // All blocking animation timers must be advanced before expiring intent.
    // Otherwise input on the last frame of a cast/swing is silently dropped.
    if (_actionWait(action) <= 0 && _bufferTime > 0) {
      _clearBuffer();
      _execute(action); // Rechecks mana/phase; never spends twice.
    } else {
      _bufferTime = _tick(_bufferTime, dt);
      if (_bufferTime == 0) _clearBuffer();
    }
  }

  bool sword() {
    if (!canSword) return false;
    _aim(swordReach, melee: true);
    swordCooldown = .52;
    swordTime = swordDuration;
    swordSide = -swordSide;
    _swordPending = true;
    return true;
  }

  bool cast() {
    if (!canCast) return false;
    _aim(spellAimRange);
    _castElement = element;
    mana -= 25;
    castTime = castDuration;
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
    invulnerable = math.max(invulnerable, .3);
    dodgeCooldown = 1.6;
    swordTime = 0;
    _swordPending = false;
    _actionTarget = null;
    _clearBuffer();
    sounds.add(BetaSound.dodge);
    return true;
  }

  double get _aimAngle =>
      moveX.abs() + moveZ.abs() > .1 ? math.atan2(moveX, moveZ) : angle;

  BetaEnemy? _findTarget(double range, {bool melee = false}) {
    BetaEnemy? best;
    var bestScore = double.infinity;
    final heading = _aimAngle;
    for (final e in enemies.where((e) => e.alive)) {
      final d = distance(x, z, e.x, e.z);
      if (d > range + (melee ? e.radius : 0) || !clearLine(x, z, e.x, e.z)) {
        continue;
      }
      final alignment = d < .001
          ? 1.0
          : ((e.x - x) * math.sin(heading) + (e.z - z) * math.cos(heading)) / d;
      // Assist inside a forward cone, never an involuntary 180-degree turn.
      if (alignment < .25) continue;
      final score =
          (d <= swordReach + e.radius ? 0 : 20) + d + (1 - alignment) * 3;
      if (score < bestScore) {
        bestScore = score;
        best = e;
      }
    }
    return best;
  }

  void _aim(double range, {bool melee = false}) {
    _actionTarget = _findTarget(range, melee: melee);
    final target = _actionTarget;
    angle = target != null ? math.atan2(target.x - x, target.z - z) : _aimAngle;
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

  /// First contact on a swept segment, including when it starts inside a body.
  static double? _circleContact(
    double ax,
    double az,
    double bx,
    double bz,
    double cx,
    double cz,
    double radius,
  ) {
    final dx = bx - ax, dz = bz - az, ox = ax - cx, oz = az - cz;
    final c = ox * ox + oz * oz - radius * radius;
    if (c <= 0) return 0;
    final a = dx * dx + dz * dz;
    if (a < .00000001) return null;
    final b = ox * dx + oz * dz, discriminant = b * b - a * c;
    if (discriminant < 0) return null;
    final t = (-b - math.sqrt(discriminant)) / a;
    return t >= 0 && t <= 1 ? t : null;
  }

  static double _terrainContact(double ax, double az, double bx, double bz) {
    var first = double.infinity;
    for (final o in obstacles) {
      final t = _circleContact(
        ax,
        az,
        bx,
        bz,
        o.x,
        o.z,
        o.radius + projectileRadius,
      );
      if (t != null) first = math.min(first, t);
    }
    for (final axis in [(ax, bx, arenaX), (az, bz, arenaZ)]) {
      final limit = axis.$3 - projectileRadius;
      if (axis.$1.abs() >= limit) return 0;
      if (axis.$2.abs() > limit) {
        first = math.min(
          first,
          (axis.$2.sign * limit - axis.$1) / (axis.$2 - axis.$1),
        );
      }
    }
    return first;
  }

  void _move(double dx, double dz) {
    final nx = (x + dx).clamp(-arenaX + .35, arenaX - .35);
    final nz = (z + dz).clamp(-arenaZ + .35, arenaZ - .35);
    bool free(double px, double pz) =>
        walkable(px, pz, .35) &&
        (dodgeTime > 0 ||
            enemies.every(
              (e) =>
                  !e.alive ||
                  distance(px, pz, e.x, e.z) >=
                      math.min(.35 + e.radius, distance(x, z, e.x, e.z)) -
                          .000001,
            ));
    if (free(nx, z)) x = nx;
    if (free(x, nz)) z = nz;
  }

  static double _tick(double timer, double dt) => math.max(0, timer - dt);

  /// Bounded substeps: resuming a suspended app never applies a huge time jump.
  void update(double elapsed) {
    if (!elapsed.isFinite ||
        elapsed <= 0 ||
        (!playing && phase != BetaPhase.won && phase != BetaPhase.lost)) {
      return;
    }
    var left = math.min(elapsed, .1);
    while (left > .000001) {
      final dt = math.min(left, 1 / 60);
      if (playing) {
        _step(dt);
      } else {
        // Finish the impact/death before showing results; no more rules or XP.
        _visualStep(dt);
        swordTime = _tick(swordTime, dt);
        castTime = _tick(castTime, dt);
        dodgeTime = _tick(dodgeTime, dt);
        resultTime = _tick(resultTime, dt);
      }
      left -= dt;
    }
  }

  void _visualStep(double dt) {
    hurtTime = _tick(hurtTime, dt);
    impactTime = _tick(impactTime, dt);
    for (final e in enemies) {
      e.flash = _tick(e.flash, dt);
      e.deathTime = _tick(e.deathTime, dt);
    }
    for (final fx in effects) {
      fx.life -= dt;
    }
    effects.removeWhere((fx) => fx.life <= 0);
    if (effects.length > 40) effects.removeRange(0, effects.length - 40);
  }

  void _step(double dt) {
    _visualStep(dt);
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
    final oldX = x, oldZ = z;
    _move(
      (dodgeTime > 0 ? _dodgeX : moveX) * speed * dt,
      (dodgeTime > 0 ? _dodgeZ : moveZ) * speed * dt,
    );
    final travelled = distance(oldX, oldZ, x, z);
    _moving = travelled > .00001;
    if (dodgeTime <= 0) stride += travelled * 3;
    if (moving && swordTime <= 0 && castTime <= 0 && dodgeTime <= 0) {
      angle = math.atan2(moveX, moveZ);
    }
    dodgeTime = _tick(dodgeTime, dt);
    swordTime = _tick(swordTime, dt);
    if (_swordPending && swordTime <= swordDuration - swordContact) {
      _swordPending = false;
      sounds.add(BetaSound.sword);
      for (final e in enemies.where((e) => e.alive)) {
        final dx = e.x - x, dz = e.z - z, d = distance(x, z, e.x, e.z);
        if (d <= swordReach + e.radius &&
            (d < .1 ||
                (dx * math.sin(angle) + dz * math.cos(angle)) / d > .4) &&
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
    _consumeInput(dt);
    for (final p in projectiles) {
      final nx = p.x + p.dx * dt * 12, nz = p.z + p.dz * dt * 12;
      p.life -= dt;
      if (p.life <= 0) continue;
      var contact = _terrainContact(p.x, p.z, nx, nz);
      BetaEnemy? victim;
      for (final e in enemies.where((e) => e.alive)) {
        final t = _circleContact(p.x, p.z, nx, nz, e.x, e.z, e.radius + .35);
        // Strict comparison makes terrain win a tie, regardless of list order.
        if (t != null && t < contact) {
          contact = t;
          victim = e;
        }
      }
      final travel = math.min(1.0, contact);
      p.x += (nx - p.x) * travel;
      p.z += (nz - p.z) * travel;
      if (contact > 1) continue;
      p.life = 0;
      if (victim case final e?) {
        final damage = switch (p.element) {
          BetaElement.fire => 27.0,
          BetaElement.water => 18.0,
          BetaElement.wind => 16.0,
          BetaElement.earth => 23.0,
        };
        _hit(
          e,
          damage + (level - 1) * 3,
          p.element,
          spell: true,
          hitX: p.x,
          hitZ: p.z,
        );
        if (p.element == BetaElement.fire && e.alive) e.burn = 3;
        if (p.element == BetaElement.water) {
          e.slow = 2.5;
          final healed = math.min(8.0, maxHp - hp);
          hp = math.min(maxHp, hp + 8);
          if (healed > 0) {
            effects.add(
              BetaEffect(
                x,
                z,
                p.element,
                text: '+${healed.ceil()}',
                kind: BetaEffectKind.heal,
              ),
            );
          }
        }
        if (p.element == BetaElement.wind) {
          for (final target in enemies.where((e) => e.alive)) {
            if (distance(p.x, p.z, target.x, target.z) < 2 &&
                clearLine(p.x, p.z, target.x, target.z)) {
              if (!identical(target, e)) {
                _hit(target, 10, p.element);
              }
              if (!target.alive) continue;
              target.cancelAttack();
              target.cooldown = .8;
              target.pushTime = .2;
              target.pushX = p.dx * 6;
              target.pushZ = p.dz * 6;
            }
          }
        }
      } else {
        effects.add(
          BetaEffect(p.x, p.z, p.element, kind: BetaEffectKind.blocked),
        );
      }
    }
    projectiles.removeWhere((p) => p.life <= 0);
    for (final e in enemies.where((e) => e.alive)) {
      if (!playing) break;
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
      if (e.pushTime > 0) {
        final step = math.min(dt, e.pushTime);
        _moveEnemy(e, e.pushX * step, e.pushZ * step);
        e.pushTime = _tick(e.pushTime, dt);
        continue;
      }
      e.cooldown = _tick(e.cooldown, dt);
      if (e.recovery > 0) {
        e.recovery = _tick(e.recovery, dt);
        continue;
      }
      if (e.windup > 0) {
        final before = e.windup;
        e.windup = _tick(e.windup, dt);
        if (before > e.strikeDuration && e.windup <= e.strikeDuration) {
          sounds.add(BetaSound.enemySwing);
        }
        if (e.windup == 0) {
          e.cooldown = e.boss ? 1.7 : 1.3;
          e.recovery = e.recoveryDuration;
          final area = e.attackArea;
          effects.add(
            BetaEffect(
              e.aimX,
              e.aimZ,
              BetaElement.earth,
              hurt: true,
              area: area,
            ),
          );
          if (e.boss) sounds.add(BetaSound.heavyImpact);
          if (area.contains(x, z) && clearLine(e.x, e.z, x, z)) {
            _hurt(e.boss ? 25 : 12);
          }
        }
        continue;
      }
      final dx = x - e.x, dz = z - e.z, d = distance(x, z, e.x, e.z);
      e.angle = math.atan2(dx, dz);
      if (d < (e.boss ? 2.6 : 1.55) &&
          e.cooldown == 0 &&
          clearLine(e.x, e.z, x, z)) {
        e.beginAttack(x, z);
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
        final oldX = e.x, oldZ = e.z;
        _moveEnemy(e, headingX * speed * dt, headingZ * speed * dt);
        final travelled = distance(oldX, oldZ, e.x, e.z);
        e.moving = travelled > .00001;
        e.stride += travelled * 4;
      }
    }
    if (!playing) return;
    if (remaining == 0) {
      if (wave == 3) {
        _finish(BetaPhase.won);
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

  void _moveEnemy(BetaEnemy e, double dx, double dz) {
    bool separating(
      double px,
      double pz,
      double ox,
      double oz,
      double radius,
    ) =>
        distance(px, pz, ox, oz) >=
        math.min(radius, distance(e.x, e.z, ox, oz)) - .000001;
    bool free(double px, double pz) =>
        walkable(px, pz, e.radius) &&
        separating(px, pz, x, z, e.radius + .35) &&
        enemies.every(
          (other) =>
              identical(e, other) ||
              !other.alive ||
              separating(px, pz, other.x, other.z, e.radius + other.radius),
        );
    if (free(e.x + dx, e.z)) e.x += dx;
    if (free(e.x, e.z + dz)) e.z += dz;
  }

  void _finish(BetaPhase result) {
    phase = result;
    resultTime = .7;
    setMovement(0, 0);
    _clearBuffer();
    _moving = false;
    _swordPending = false;
    if (result == BetaPhase.lost) swordTime = castTime = dodgeTime = 0;
    projectiles.clear();
  }

  void _hit(
    BetaEnemy e,
    double damage,
    BetaElement source, {
    bool spell = false,
    double? hitX,
    double? hitZ,
  }) {
    if (!e.alive) return;
    e.hp = math.max(0, e.hp - damage);
    e.flash = .22;
    impactTime = .14;
    effects.add(
      BetaEffect(
        hitX ?? e.x,
        hitZ ?? e.z,
        source,
        text: '${damage.round()}',
        kind: spell ? BetaEffectKind.spell : BetaEffectKind.impact,
      ),
    );
    sounds.add(
      spell
          ? switch (source) {
              BetaElement.fire => BetaSound.fireImpact,
              BetaElement.water => BetaSound.waterImpact,
              BetaElement.wind => BetaSound.windImpact,
              BetaElement.earth => BetaSound.earthImpact,
            }
          : BetaSound.impact,
    );
    if (!e.alive) _kill(e);
  }

  void _kill(BetaEnemy e) {
    if (e._rewarded) return;
    e._rewarded = true;
    e.deathTime = deathDuration;
    e.cancelAttack();
    e.moving = false;
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
    hurtTime = .28;
    impactTime = .18;
    effects.add(
      BetaEffect(x, z, element, text: '-${damage.round()}', hurt: true),
    );
    sounds.add(BetaSound.hurt);
    if (hp == 0) {
      _finish(BetaPhase.lost);
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
    message = switch (wave) {
      1 => 'GOBLINS · desvie para o lado da estocada',
      2 => 'BRUTO · contorne a varredura e ataque na recuperação',
      _ => 'GUARDIÃO · saia do círculo antes do impacto',
    };
    messageTime = 4;
  }
}
