import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../game_domain/beta_session.dart';

Color betaElementColor(BetaElement element) => switch (element) {
  BetaElement.fire => const Color(0xFFEAAF52),
  BetaElement.water => const Color(0xFF72BEC9),
  BetaElement.wind => const Color(0xFFB4DBB2),
  BetaElement.earth => const Color(0xFFD2B38A),
};

class _V {
  const _V(this.x, this.y, this.z);
  final double x, y, z;
  _V operator +(_V v) => _V(x + v.x, y + v.y, z + v.z);
  _V operator -(_V v) => _V(x - v.x, y - v.y, z - v.z);
  _V operator *(double scale) => _V(x * scale, y * scale, z * scale);
  double dot(_V v) => x * v.x + y * v.y + z * v.z;
  _V cross(_V v) => _V(y * v.z - z * v.y, z * v.x - x * v.z, x * v.y - y * v.x);
  _V get unit => this * (1 / math.sqrt(dot(this)));
}

class _Face {
  const _Face(
    this.points,
    this.color, {
    this.unlit = false,
    this.ground = false,
  });
  final List<_V> points;
  final Color color;
  final bool unlit;
  final bool ground;
}

class _Projected {
  const _Projected(this.path, this.color, this.depth, this.layer);
  final Path path;
  final Color color;
  final double depth;
  final int layer;
}

/// Small software-projected 3D scene: real XYZ meshes, perspective, directional
/// shading and face sorting. Deliberately no new native renderer or GPU plugin.
/// Not a general 3D engine: no depth buffer, skeletal assets or vertical physics.
class BetaArenaPainter extends CustomPainter {
  BetaArenaPainter(this.run)
    : _cameraX = run.x * .65,
      _cameraZ = run.z,
      _heroAngle = run.angle;
  final BetaSession run;
  double _cameraX, _cameraZ, _heroAngle;
  double _clock = 0;
  final _enemyAngles = <BetaEnemy, double>{};
  final _labelBounds = <Rect>[];
  final _labels = <(String, double, Color), TextPainter>{};
  static const labelCacheLimit = 64;
  @visibleForTesting
  int get cachedLabelCount => _labels.length;

  void dispose() {
    for (final text in _labels.values) {
      text.dispose();
    }
    _labels.clear();
    _labelBounds.clear();
    _enemyAngles.clear();
  }

  static final _scenery = _buildScenery();
  late _V _camera, _right, _up, _forward;
  late Size _size;
  late double _focal;
  late double _horizon;

  void advance(double elapsed) {
    if (!elapsed.isFinite || elapsed <= 0 || (!run.playing && !run.settling)) {
      return;
    }
    final dt = elapsed.clamp(0.0, .1);
    _clock += dt;
    final follow = 1 - math.exp(-6 * dt);
    _cameraX += (run.x * .65 - _cameraX) * follow;
    _cameraZ += (run.z - _cameraZ) * follow;
    double turn(double from, double to) =>
        from +
        math.atan2(math.sin(to - from), math.cos(to - from)) *
            (1 - math.exp(-24 * dt));
    _heroAngle = turn(_heroAngle, run.angle);
    _enemyAngles.removeWhere((e, _) => !run.enemies.contains(e));
    for (final e in run.enemies) {
      _enemyAngles[e] = turn(_enemyAngles[e] ?? e.angle, e.angle);
    }
  }

  static void _box(
    List<_Face> faces,
    _V center,
    _V size,
    Color color, {
    double yaw = 0,
    double pitch = 0,
    _V Function(_V)? transform,
  }) {
    final sx = size.x / 2, sy = size.y / 2, sz = size.z / 2;
    final c = math.cos(yaw), s = math.sin(yaw);
    final cp = math.cos(pitch), sp = math.sin(pitch);
    final points =
        [
          _V(-sx, -sy, -sz),
          _V(sx, -sy, -sz),
          _V(sx, sy, -sz),
          _V(-sx, sy, -sz),
          _V(-sx, -sy, sz),
          _V(sx, -sy, sz),
          _V(sx, sy, sz),
          _V(-sx, sy, sz),
        ].map((p) {
          final py = p.y * cp - p.z * sp;
          final pz = p.y * sp + p.z * cp;
          final point = center + _V(p.x * c + pz * s, py, -p.x * s + pz * c);
          return transform?.call(point) ?? point;
        }).toList();
    for (final side in const [
      [4, 5, 6, 7],
      [1, 0, 3, 2],
      [0, 4, 7, 3],
      [5, 1, 2, 6],
      [3, 7, 6, 2],
      [0, 1, 5, 4],
    ]) {
      faces.add(_Face(side.map((i) => points[i]).toList(), color));
    }
  }

  // Oriented segment: hands, weapon and articulated limbs share endpoints.
  static void _beam(
    List<_Face> faces,
    _V a,
    _V b,
    double width,
    Color color,
    _V Function(_V) transform, {
    double? depth,
  }) {
    final delta = b - a;
    final length = math.sqrt(delta.dot(delta));
    if (length < .001) return;
    final up = delta.unit;
    final right = up
        .cross(up.y.abs() < .9 ? const _V(0, 1, 0) : const _V(0, 0, 1))
        .unit;
    final forward = right.cross(up);
    _box(
      faces,
      const _V(0, 0, 0),
      _V(width, length, depth ?? width),
      color,
      transform: (p) =>
          transform((a + b) * .5 + right * p.x + up * p.y + forward * p.z),
    );
  }

  static List<_Face> _buildScenery() {
    final faces = <_Face>[];
    for (var x = -9; x < 9; x += 2) {
      for (var z = -11; z < 11; z += 2) {
        final path = x.abs() < 3;
        final color = Color(
          path
              ? ((x + z) % 4 == 0 ? 0xFF8F8A6B : 0xFF999276)
              : ((x + z) % 4 == 0 ? 0xFF4C6653 : 0xFF536E58),
        );
        faces.add(
          _Face(
            [
              _V(x.toDouble(), -.02, z.toDouble()),
              _V(x.toDouble(), -.02, z + 2.0),
              _V(x + 2.0, -.02, z + 2.0),
              _V(x + 2.0, -.02, z.toDouble()),
            ],
            color,
            ground: true,
          ),
        );
      }
    }
    for (final o in BetaSession.obstacles) {
      _box(
        faces,
        _V(o.x, .16, o.z),
        const _V(1.6, .32, 1.6),
        const Color(0xFF666D5E),
      );
      _box(
        faces,
        _V(o.x, o.height / 2, o.z),
        _V(.95, o.height, .95),
        const Color(0xFFABA585),
      );
      _box(
        faces,
        _V(o.x, o.height, o.z),
        const _V(1.35, .3, 1.35),
        const Color(0xFFCAC09B),
      );
    }
    for (var z = -10; z <= 10; z += 4) {
      for (final x in [-9.0, 9.0]) {
        _box(
          faces,
          _V(x, .6, z.toDouble()),
          const _V(.5, 1.2, 3.8),
          const Color(0xFF68786A),
        );
        _box(
          faces,
          _V(x, .85, z + 1.9),
          const _V(.9, 1.7, .9),
          const Color(0xFFB4AC88),
        );
      }
    }
    for (final x in [-5.5, 5.5]) {
      _box(
        faces,
        _V(x, 1.6, -10),
        const _V(1.2, 3.2, 1.3),
        const Color(0xFF879580),
      );
      _box(
        faces,
        _V(x, 3.3, -10),
        const _V(1.7, .35, 1.7),
        const Color(0xFFBCB695),
      );
    }
    _box(
      faces,
      const _V(0, .25, -9.5),
      const _V(6.5, .5, 2),
      const Color(0xFF788773),
    );
    for (var i = 0; i < 8; i++) {
      final x = i.isEven ? -7.0 : 7.0, z = -8 + (i ~/ 2) * 5.0;
      _box(
        faces,
        _V(x, .3, z),
        const _V(.9, .6, 1.1),
        const Color(0xFF758976),
        yaw: i * .3,
      );
      _box(
        faces,
        _V(x + .35, .5, z),
        const _V(.45, 1, .45),
        const Color(0xFF3D664F),
      );
    }
    return faces;
  }

  void _disc(
    List<_Face> faces,
    double x,
    double z,
    double radius,
    Color color, {
    double height = .012,
  }) {
    faces.add(
      _Face(
        [
          for (var i = 0; i < 28; i++)
            _V(
              x + math.sin(i * math.pi / 14) * radius,
              height,
              z + math.cos(i * math.pi / 14) * radius,
            ),
        ],
        color,
        unlit: true,
        ground: true,
      ),
    );
  }

  void _ring(
    List<_Face> faces,
    double x,
    double z,
    double radius,
    Color color, {
    double fraction = 1,
  }) {
    for (var i = 0; i < (28 * fraction).ceil(); i++) {
      final a = i * math.pi / 14, b = (i + 1) * math.pi / 14;
      faces.add(
        _Face(
          [
            _V(x + math.sin(a) * radius, .025, z + math.cos(a) * radius),
            _V(x + math.sin(b) * radius, .025, z + math.cos(b) * radius),
            _V(
              x + math.sin(b) * (radius - .09),
              .025,
              z + math.cos(b) * (radius - .09),
            ),
            _V(
              x + math.sin(a) * (radius - .09),
              .025,
              z + math.cos(a) * (radius - .09),
            ),
          ],
          color,
          unlit: true,
          ground: true,
        ),
      );
    }
  }

  void _attackArea(
    List<_Face> faces,
    BetaAttackArea area,
    double progress, {
    double opacity = 1,
    bool impact = false,
  }) {
    progress = progress.clamp(0.0, 1.0);
    final points = area.outline.map((p) => _V(p.x, .035, p.z)).toList();
    faces.add(
      _Face(
        points,
        (impact ? const Color(0xFFA88D60) : const Color(0xFFA94832)).withValues(
          alpha: (impact ? .12 : .16 + progress * .15) * opacity,
        ),
        ground: true,
        unlit: true,
      ),
    );
    final lengths = [
      for (var i = 0; i < points.length; i++)
        math.sqrt(
          (points[(i + 1) % points.length] - points[i]).dot(
            points[(i + 1) % points.length] - points[i],
          ),
        ),
    ];
    var remaining = lengths.fold<double>(0, (a, b) => a + b) * progress;
    void line(_V a, _V b, Color color) {
      final delta = b - a;
      if (delta.dot(delta) < .000001) return;
      final side = _V(-delta.z, 0, delta.x).unit * .035;
      faces.add(
        _Face(
          [a - side, b - side, b + side, a + side],
          color.withValues(alpha: opacity),
          ground: true,
          unlit: true,
        ),
      );
    }

    for (var i = 0; i < points.length; i++) {
      final a = points[i], b = points[(i + 1) % points.length];
      line(a, b, impact ? const Color(0xFFB69B6D) : const Color(0xFFB66142));
      if (!impact && remaining > 0 && lengths[i] > .00001) {
        line(
          a,
          a + (b - a) * (remaining / lengths[i]).clamp(0.0, 1.0),
          const Color(0xFFFFD79A),
        );
      }
      remaining -= lengths[i];
    }
  }

  void _actor(
    List<_Face> faces, {
    required double x,
    required double z,
    required double angle,
    required double stride,
    required bool moving,
    BetaEnemy? enemy,
  }) {
    final hero = enemy == null, boss = enemy?.boss ?? false;
    final brute = enemy?.kind == BetaEnemyKind.brute;
    final scale = boss
        ? 1.65
        : enemy?.kind == BetaEnemyKind.brute
        ? 1.15
        : 1.0;
    final casting = hero && run.castTime > 0;
    final dodging = hero && run.dodgeTime > 0;
    final dead = hero ? run.phase == BetaPhase.lost : !enemy.alive;
    final fall = dead
        ? (1 -
                  (hero
                      ? run.resultTime / .7
                      : enemy.deathTime / BetaSession.deathDuration))
              .clamp(0.0, 1.0)
        : 0.0;
    final recoil = (hero ? run.hurtTime / .28 : enemy.flash / .22).clamp(
      0.0,
      1.0,
    );
    final bob = moving && !dodging
        ? math.sin(stride * 2).abs() * .05
        : math.sin(_clock * 2) * .018;
    double ease(double t) {
      t = t.clamp(0.0, 1.0);
      return t * t * (3 - 2 * t);
    }

    var swing = 0.0, lift = 0.0, lunge = 0.0, thrust = 0.0;
    if (hero && run.swordTime > 0) {
      final elapsed = BetaSession.swordDuration - run.swordTime;
      if (elapsed < .09) {
        swing = -1.25 * ease(elapsed / .09);
      } else if (elapsed < BetaSession.swordContact + .07) {
        swing = -1.25 + 2.5 * ease((elapsed - .09) / .14);
      } else {
        swing = 1.25 * (1 - ease((elapsed - .23) / .21));
      }
      swing *= run.swordSide;
      lift = .18;
      lunge =
          math.sin(ease(elapsed / BetaSession.swordDuration) * math.pi) * .18;
    } else if (!hero && enemy.windup > 0) {
      final prepare = ease(
        (enemy.preparation - enemy.windup) / (enemy.preparation * .6),
      );
      final strike = ease(1 - enemy.windup / enemy.strikeDuration);
      switch (enemy.attackShape) {
        case BetaAttackShape.thrust:
          thrust = -.22 * prepare + strike * .85;
          lunge = strike * .27;
        case BetaAttackShape.sweep:
          swing = -1.35 * prepare + strike * 2.7;
          lift = .15;
          lunge = strike * .13;
        case BetaAttackShape.slam:
          lift = prepare * (1 - strike);
          lunge = strike * .22;
      }
    } else if (!hero && enemy.recovery > 0) {
      final recover = 1 - ease(1 - enemy.recovery / enemy.recoveryDuration);
      lunge = (brute ? .13 : .22) * recover;
      if (brute) swing = 1.35 * recover;
      if (enemy.attackShape == BetaAttackShape.thrust) thrust = .63 * recover;
    }
    final castLift = casting
        ? ease((BetaSession.castDuration - run.castTime) / .12)
        : 0.0;
    var body = hero
        ? const Color(0xFF356D79)
        : boss
        ? const Color(0xFF898F7C)
        : const Color(0xFF715039);
    var skin = hero
        ? const Color(0xFFE3C89E)
        : boss
        ? const Color(0xFFABB09B)
        : const Color(0xFF9CAF65);
    body = Color.lerp(body, const Color(0xFFFFEBC3), recoil * .8)!;
    skin = Color.lerp(skin, const Color(0xFFFFEBC3), recoil * .8)!;
    final yaw = angle + swing * .16;
    final tilt =
        -fall * math.pi / 2 - recoil * .12 + (dodging ? .55 : lunge * .5);
    final ct = math.cos(tilt), st = math.sin(tilt);
    final cy = math.cos(yaw), sy = math.sin(yaw);
    _V world(_V p) {
      final py = p.y * ct - p.z * st;
      final pz = p.y * st + p.z * ct + lunge;
      return _V(
        x + (p.x * cy + pz * sy) * scale,
        (py + bob - (dodging ? .12 : 0) + fall * .22) * scale,
        z + (-p.x * sy + pz * cy) * scale,
      );
    }

    void part(
      double px,
      double py,
      double pz,
      double w,
      double h,
      double d,
      Color color, {
      double twist = 0,
      double pitch = 0,
    }) => _box(
      faces,
      _V(px, py, pz),
      _V(w, h, d),
      color,
      yaw: twist,
      pitch: pitch,
      transform: world,
    );
    _disc(faces, x, z, .56 * scale, const Color(0x550E2726));
    final walk = moving && !dodging ? math.sin(stride) * .3 : 0.0;
    for (final side in [-1.0, 1.0]) {
      final foot = _V(
        side * .18,
        .1 + math.max(0, walk * side) * .22,
        -walk * side + (dodging ? side * .18 : 0),
      );
      final knee = _V(side * .18, .32, -walk * side * .5 + .08);
      _beam(faces, _V(side * .18, .57, 0), knee, .22, body, world);
      _beam(faces, knee, foot, .2, const Color(0xFF313F3C), world);
      part(
        foot.x,
        foot.y,
        foot.z + .07,
        .25,
        .17,
        .36,
        const Color(0xFF313F3C),
      );
    }
    part(0, .85, 0, brute ? .88 : .68, .74, brute ? .5 : .4, body);
    part(0, .56, 0, .71, .13, .45, const Color(0xFFC3A46A));
    if (hero) {
      part(
        0,
        .9,
        -.3 - walk.abs() * .25,
        .68,
        .83,
        .09,
        const Color(0xFF233F4A),
        pitch: -.08 - walk.abs() * .4,
      );
    }
    part(0, 1.46, .02, .51, .48, .48, skin);
    part(0, 1.7, -.03, .61, .18, .55, body);
    final eyes = boss ? const Color(0xFFE7CA7C) : const Color(0xFF253331);
    part(-.13, 1.5, .27, .085, .085, .04, eyes);
    part(.13, 1.5, .27, .085, .085, .04, eyes);
    if (!hero && !boss) {
      part(-.38, 1.49, -.02, .35, .16, .19, skin, twist: -.35);
      part(.38, 1.49, -.02, .35, .16, .19, skin, twist: .35);
      part(-.13, 1.25, .29, .07, .18, .08, const Color(0xFFF0DDB1));
      part(.13, 1.25, .29, .07, .18, .08, const Color(0xFFF0DDB1));
    }
    final hand = _V(
      .42 +
          math.sin(swing) * .3 -
          (!hero && !brute && !boss ? math.max(0, thrust) * .45 : 0),
      .77 + lift * .65,
      .25 + math.cos(swing) * .17 + walk * .4 + thrust,
    );
    final leftHand = _V(
      -.45 + castLift * .18,
      .69 + castLift * .54,
      .16 + castLift * .55 - walk * .5,
    );
    for (final entry in [(-1.0, leftHand), (1.0, hand)]) {
      final shoulder = _V(entry.$1 * .39, 1.12, 0);
      final elbow = _V(
        entry.$1 * .52,
        (shoulder.y + entry.$2.y) * .5,
        entry.$2.z * .5 - .1,
      );
      _beam(faces, shoulder, elbow, .23, body, world);
      _beam(faces, elbow, entry.$2, .19, skin, world);
      part(entry.$2.x, entry.$2.y, entry.$2.z, .23, .21, .23, skin);
    }
    if (boss) {
      part(-.47, 1.17, 0, .5, .42, .56, const Color(0xFFBBC09F));
      part(.47, 1.17, 0, .5, .42, .56, const Color(0xFFBBC09F));
      part(0, 1.01, .25, .22, .23, .1, const Color(0xFFDDB55A));
      part(0, 1.7, .05, .18, .27, .6, const Color(0xFF737C72));
      part(0, 1.25, .24, .58, .12, .14, const Color(0xFF737C72));
    } else if (brute) {
      part(-.48, 1.16, 0, .38, .3, .5, const Color(0xFF9D7952));
      part(.48, 1.16, 0, .38, .3, .5, const Color(0xFF9D7952));
    }
    final blade = hero
        ? betaElementColor(run.element)
        : const Color(0xFFCAC5A9);
    final bladePitch = hero
        ? .12 + castLift * -.45
        : boss
        ? lift * 1.8 - .12
        : .03;
    final direction = _V(
      math.sin(swing) * math.cos(bladePitch),
      math.sin(bladePitch),
      math.cos(swing) * math.cos(bladePitch),
    );
    final guard = hand + direction * .24;
    final tip =
        guard +
        direction *
            (boss
                ? .95
                : brute
                ? 1.15
                : hero
                ? 1.25
                : .95);
    _beam(
      faces,
      hand - direction * .12,
      guard,
      .13,
      const Color(0xFF4C3830),
      world,
    );
    _beam(
      faces,
      guard,
      tip,
      boss || brute ? .12 : .13,
      boss || brute ? const Color(0xFF5A4635) : blade,
      world,
      depth: boss || brute ? .12 : .07,
    );
    final cross = _V(math.cos(swing), 0, -math.sin(swing)) * .2;
    if (boss || brute) {
      _box(
        faces,
        tip,
        boss ? const _V(.8, .47, .4) : const _V(.72, .42, .13),
        boss ? const Color(0xFFC4BD94) : const Color(0xFFBBB997),
        yaw: swing,
        pitch: -bladePitch,
        transform: world,
      );
    } else {
      _beam(
        faces,
        guard - cross,
        guard + cross,
        .09,
        const Color(0xFFC3A46A),
        world,
      );
    }
    // Short, opaque arc: readable blade motion without a full-screen glow.
    final elapsed = BetaSession.swordDuration - run.swordTime;
    if (hero && run.swordTime > 0 && elapsed >= .1 && elapsed <= .24) {
      for (var i = 0; i < 5; i++) {
        final a = swing - run.swordSide * i * .13;
        final b = a - run.swordSide * .13;
        _V arc(double angle, double radius) =>
            world(_V(math.sin(angle) * radius, .96, math.cos(angle) * radius));
        faces.add(
          _Face(
            [arc(a, 1.8), arc(b, 1.8), arc(b, 1.67), arc(a, 1.67)],
            Color.lerp(blade, const Color(0xFFF7EDCB), 1 - i / 5)!,
            unlit: true,
          ),
        );
      }
    }
    if (casting) {
      final charge = 1 - run.castTime / BetaSession.castDuration;
      _spellShape(
        faces,
        world(leftHand + const _V(0, .05, .18)),
        run.element,
        yaw: yaw,
        power: .35 + charge * .65,
      );
      _ring(faces, x, z, .7 + charge * .2, blade, fraction: charge);
    }
    if (hero && run.protection > 0) {
      _ring(
        faces,
        x,
        z,
        .85,
        const Color(0xFFDFC88B),
        fraction: run.protection / 2,
      );
      for (var i = 0; i < 3; i++) {
        final a = _clock * 1.8 + i * math.pi * 2 / 3;
        _box(
          faces,
          _V(x + math.sin(a) * .72, .5, z + math.cos(a) * .72),
          const _V(.3, .38, .12),
          const Color(0xFFB6A17B),
          yaw: a,
        );
      }
    }
    if (hero && run.dodgeTime > 0) {
      _ring(faces, x, z, .7, const Color(0xFFB4DBB2));
    }
  }

  void _gem(List<_Face> faces, _V center, _V size, Color color, double yaw) {
    final c = math.cos(yaw), s = math.sin(yaw);
    _V point(double x, double y, double z) =>
        center +
        _V(
          x * size.x * c + z * size.z * s,
          y * size.y,
          -x * size.x * s + z * size.z * c,
        );
    final rim = [
      point(1, 0, 0),
      point(0, 0, -1),
      point(-1, 0, 0),
      point(0, 0, 1),
    ];
    for (var i = 0; i < 4; i++) {
      final next = (i + 1) % 4;
      faces.add(_Face([point(0, 1, 0), rim[i], rim[next]], color));
      faces.add(_Face([point(0, -1, 0), rim[next], rim[i]], color));
    }
  }

  /// Small silhouettes, not just recolored cubes: ember, drop, spiral, rock.
  void _spellShape(
    List<_Face> faces,
    _V center,
    BetaElement element, {
    double yaw = 0,
    double power = 1,
  }) {
    final color = betaElementColor(element);
    _V local(_V p) =>
        center +
        _V(
              p.x * math.cos(yaw) + p.z * math.sin(yaw),
              p.y,
              -p.x * math.sin(yaw) + p.z * math.cos(yaw),
            ) *
            power;
    switch (element) {
      case BetaElement.fire:
        _gem(faces, center, _V(.23, .28, .38) * power, color, yaw);
        _gem(
          faces,
          local(const _V(0, .13, -.15)),
          _V(.1, .21, .2) * power,
          const Color(0xFFFFDF94),
          yaw,
        );
      case BetaElement.water:
        _gem(faces, center, _V(.22, .34, .25) * power, color, yaw);
        _gem(
          faces,
          local(const _V(-.08, .12, .1)),
          _V(.08, .13, .12) * power,
          const Color(0xFFCFEBDF),
          yaw,
        );
      case BetaElement.wind:
        for (var i = 0; i < 9; i++) {
          final a = _clock * 9 + i * .6, b = a + .4;
          _beam(
            faces,
            _V(math.cos(a) * .33, math.sin(a) * .25, (i - 4) * .05),
            _V(math.cos(b) * .33, math.sin(b) * .25, (i - 4) * .05),
            .055,
            i.isEven ? color : const Color(0xFFE4E5C3),
            local,
          );
        }
      case BetaElement.earth:
        _box(
          faces,
          center,
          _V(.42, .34, .46) * power,
          const Color(0xFFA48D68),
          yaw: yaw + _clock * 3,
          pitch: .35,
        );
        _gem(
          faces,
          local(const _V(.15, .14, 0)),
          _V(.17, .19, .17) * power,
          color,
          yaw,
        );
    }
  }

  void _spellImpact(List<_Face> faces, BetaEffect fx) {
    final progress = (1 - fx.life / .65).clamp(0.0, 1.0);
    final blocked = fx.kind == BetaEffectKind.blocked;
    final color = betaElementColor(fx.element);
    final scale = blocked ? .4 : 1.0;
    final radius = (fx.element == BetaElement.wind ? 2 : .9) * scale;
    if (fx.element == BetaElement.water || fx.element == BetaElement.wind) {
      _ring(
        faces,
        fx.x,
        fx.z,
        .15 + math.sqrt(progress) * (radius - .15),
        color.withValues(alpha: 1 - progress),
      );
    }
    for (var i = 0; i < 6; i++) {
      final a = i * math.pi / 3;
      final spread = .15 + progress * (radius - .15);
      final point = _V(
        fx.x + math.sin(a) * spread,
        .12 +
            math.sin(progress * math.pi) *
                (fx.element == BetaElement.fire ? 1.4 : .6),
        fx.z + math.cos(a) * spread,
      );
      final size = (.06 + (1 - progress) * .14) * scale;
      if (fx.element == BetaElement.earth) {
        _box(faces, point, _V(size, size * 2, size), color, yaw: a + progress);
      } else {
        _gem(
          faces,
          point,
          _V(size, size * (fx.element == BetaElement.fire ? 2 : 1), size),
          color,
          a,
        );
      }
    }
  }

  Offset? _project(_V p) {
    final delta = p - _camera, depth = delta.dot(_forward);
    if (depth < .3) return null;
    return Offset(
      _size.width / 2 + delta.dot(_right) * _focal / depth,
      _size.height * _horizon - delta.dot(_up) * _focal / depth,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    _labelBounds.clear();
    _size = size;
    final wide = size.width > size.height;
    _focal = wide ? size.height * 1.1 : size.width * 1.35;
    _horizon = wide ? .57 : .47;
    final target = _V(_cameraX, 0, _cameraZ - 1.7);
    _camera = _V(target.x, 11, _cameraZ + 13);
    _forward = (target - _camera).unit;
    _right = _forward.cross(const _V(0, 1, 0)).unit;
    _up = _right.cross(_forward);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF243F3D),
    );
    final shake = run.impactTime / .18;
    canvas.translate(
      math.sin(_clock * 85) * shake * 1.8,
      math.cos(_clock * 73) * shake * 1.2,
    );
    final faces = <_Face>[..._scenery];
    _ring(faces, 0, -9, 1.5, const Color(0xFFC5B77C));
    for (final x in [-5.5, 5.5]) {
      _box(
        faces,
        _V(x, 3.65 + math.sin(run.time * 5 + x) * .06, -10),
        const _V(.35, .55, .35),
        const Color(0xFFE8B558),
        yaw: run.time,
      );
    }
    final aim = run.aimTarget;
    if (aim != null) {
      final melee = run.inSwordRange(aim);
      _ring(
        faces,
        aim.x,
        aim.z,
        aim.radius + .24,
        melee ? const Color(0xFFFFD38A) : const Color(0xFF8BC9D4),
        fraction: melee ? 1 : .75,
      );
    }
    if (run.playing) {
      final dx = math.sin(run.aimDirection), dz = math.cos(run.aimDirection);
      _V arrow(double forward, double side) => _V(
        run.x + dx * forward + dz * side,
        .03,
        run.z + dz * forward - dx * side,
      );
      faces.add(
        _Face(
          [arrow(1.02, 0), arrow(.73, -.13), arrow(.73, .13)],
          const Color(0xFFD5D6AB),
          unlit: true,
          ground: true,
        ),
      );
    }
    for (final e in run.enemies.where((e) => e.alive || e.deathTime > 0)) {
      if (e.alive && e.slow > 0) {
        _ring(faces, e.x, e.z, e.radius + .15, const Color(0xFF81BCCB));
      }
      if (e.alive && e.burn > 0) {
        _gem(
          faces,
          _V(e.x, e.boss ? 2.5 : 1.8, e.z),
          const _V(.13, .25, .13),
          const Color(0xFFE3A347),
          run.time * 3,
        );
      }
      if (e.windup > 0) {
        _attackArea(faces, e.attackArea, 1 - e.windup / e.preparation);
      } else if (e.alive && e.recovery > 0) {
        _ring(
          faces,
          e.x,
          e.z,
          e.radius + .4,
          const Color(0xFFADD0AC),
          fraction: e.recovery / e.recoveryDuration,
        );
      }
      _actor(
        faces,
        x: e.x,
        z: e.z,
        angle: _enemyAngles[e] ?? e.angle,
        stride: e.stride,
        moving: e.moving,
        enemy: e,
      );
    }
    _ring(faces, run.x, run.z, .65, const Color(0xFFC9CE9C));
    _actor(
      faces,
      x: run.x,
      z: run.z,
      angle: _heroAngle,
      stride: run.stride,
      moving: run.moving,
    );
    for (final p in run.projectiles) {
      final yaw = math.atan2(p.dx, p.dz);
      _spellShape(faces, _V(p.x, .85, p.z), p.element, yaw: yaw);
      for (var i = 1; i <= 3; i++) {
        final offset = i * .25;
        _gem(
          faces,
          _V(p.x - p.dx * offset, .83, p.z - p.dz * offset),
          _V(.12, .1, .17) * (1 - i * .22),
          betaElementColor(p.element),
          yaw,
        );
      }
    }
    for (final fx in run.effects) {
      if (fx.area case final area?) {
        _attackArea(faces, area, 1, opacity: fx.life / .65, impact: true);
        if (area.shape == BetaAttackShape.slam) {
          for (var i = 0; i < 8; i++) {
            final angle = i * math.pi / 4, life = fx.life / .65;
            final radius = area.reach * (1 - life * .45);
            _box(
              faces,
              _V(
                area.x + math.sin(angle) * radius,
                math.sin(life * math.pi) * .45 + .08,
                area.z + math.cos(angle) * radius,
              ),
              _V(.13, .2, .12) * life,
              const Color(0xFFBAA27B),
              yaw: angle,
            );
          }
        }
        continue;
      }
      if (fx.kind == BetaEffectKind.spell ||
          fx.kind == BetaEffectKind.blocked) {
        _spellImpact(faces, fx);
        continue;
      }
      if (fx.kind == BetaEffectKind.heal) {
        _ring(
          faces,
          fx.x,
          fx.z,
          .6 + (.65 - fx.life) * .5,
          const Color(0xFFB4DBB2).withValues(alpha: fx.life / .65),
        );
        continue;
      }
      if (fx.text == null) {
        _ring(
          faces,
          fx.x,
          fx.z,
          .3 + (1 - fx.life / .65) * 1.4,
          const Color(0xFFCBAF79),
        );
      }
      for (var i = 0; i < 4; i++) {
        final a = i * math.pi / 2, spread = (.65 - fx.life) * 1.6;
        _box(
          faces,
          _V(
            fx.x + math.sin(a) * spread,
            .6 + fx.life,
            fx.z + math.cos(a) * spread,
          ),
          const _V(.09, .09, .09),
          betaElementColor(fx.element),
        );
      }
    }
    final projected = <_Projected>[];
    final light = const _V(-.5, 1, .6).unit;
    for (final face in faces) {
      final normal = (face.points[1] - face.points[0]).cross(
        face.points[2] - face.points[0],
      );
      if (normal.dot(normal) < .00000001) continue;
      if (!face.unlit && normal.dot(_camera - face.points[0]) <= 0) continue;
      final points = face.points.map(_project).toList();
      if (points.any((p) => p == null)) continue;
      final path = Path()..addPolygon(points.cast<Offset>(), true);
      if (!path.getBounds().overlaps(Offset.zero & size)) continue;
      final depth =
          face.points.fold<double>(
            0,
            (sum, p) => sum + (p - _camera).dot(_forward),
          ) /
          face.points.length;
      final shade = face.unlit
          ? 1.0
          : .54 + .46 * math.max(0, normal.unit.dot(light));
      final c = face.color;
      var color = Color.fromARGB(
        (c.a * 255).round(),
        (c.r * 255 * shade).round(),
        (c.g * 255 * shade).round(),
        (c.b * 255 * shade).round(),
      );
      if (depth > 23 && !face.unlit) {
        color = Color.lerp(
          color,
          const Color(0xFF39524B),
          ((depth - 23) / 30).clamp(0.0, .5),
        )!;
      }
      projected.add(
        _Projected(path, color, depth, face.ground ? (face.unlit ? 1 : 0) : 2),
      );
    }
    // Floor tiles must never cover legs/weapons due to average-depth sorting.
    projected.sort(
      (a, b) => a.layer == b.layer
          ? b.depth.compareTo(a.depth)
          : a.layer.compareTo(b.layer),
    );
    final paint = Paint()..isAntiAlias = true;
    for (final face in projected) {
      canvas.drawPath(face.path, paint..color = face.color);
    }
    for (final e in run.enemies.where(
      (e) =>
          e.alive &&
          (e.hp < e.maxHp ||
              identical(e, aim) ||
              e.windup > 0 ||
              e.recovery > 0),
    )) {
      final p = _project(_V(e.x, e.boss ? 3.3 : 2.1, e.z));
      if (p == null) continue;
      canvas.drawRect(
        Rect.fromLTWH(p.dx - 17, p.dy, 34, 4),
        Paint()..color = const Color(0xFF213A36),
      );
      canvas.drawRect(
        Rect.fromLTWH(p.dx - 16, p.dy + 1, 32 * e.hp / e.maxHp, 2),
        Paint()..color = const Color(0xFFE8AD68),
      );
      if (identical(e, aim) || e.windup > 0 || e.recovery > 0) {
        final state = e.windup > 0
            ? e.attackLabel
            : e.recovery > 0
            ? 'Recuperando'
            : '${e.label}${e.burn > 0 ? ' · Queima' : ''}${e.slow > 0 ? ' · Lento' : ''}';
        _label(
          canvas,
          p - const Offset(0, 3),
          state,
          e.recovery > 0 ? const Color(0xFFB4DBB2) : const Color(0xFFE9DFBB),
          size: 10,
        );
      }
    }
    if (run.protection > 0 && run.playing) {
      final p = _project(_V(run.x, 2.15, run.z));
      if (p != null) {
        _label(
          canvas,
          p,
          'Proteção ${run.protection.ceil()}s',
          const Color(0xFFE7CE94),
          size: 10,
        );
      }
    }
    for (final fx in run.effects.where((e) => e.text != null)) {
      final p = _project(_V(fx.x, 2.0 + (.65 - fx.life), fx.z));
      if (p == null) continue;
      _label(
        canvas,
        p - const Offset(0, 20),
        fx.text!,
        fx.kind == BetaEffectKind.heal
            ? const Color(0xFFB4DBB2)
            : fx.hurt
            ? const Color(0xFFFFBA9B)
            : const Color(0xFFFFE7A3),
      );
    }
    canvas.restore();
  }

  void _label(
    Canvas canvas,
    Offset p,
    String value,
    Color color, {
    double size = 15,
  }) {
    final key = (value, size, color);
    final text =
        _labels.remove(key) ??
        (TextPainter(
          text: TextSpan(
            text: value,
            style: TextStyle(
              color: color,
              fontFamily: 'Roboto',
              fontSize: size,
              fontWeight: FontWeight.bold,
              shadows: const [
                Shadow(color: Color(0xFF1C312D), offset: Offset(1, 1)),
              ],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout());
    _labels[key] = text;
    if (_labels.length > labelCacheLimit) {
      _labels.remove(_labels.keys.first)!.dispose();
    }
    var origin = p - Offset(text.width / 2, text.height);
    for (var attempt = 0; attempt < _labelBounds.length; attempt++) {
      final overlaps = _labelBounds.where(
        (rect) => rect.inflate(2).overlaps(origin & text.size),
      );
      if (overlaps.isEmpty) break;
      final top = overlaps.map((rect) => rect.top).reduce(math.min);
      origin = Offset(origin.dx, top - text.height - 3);
    }
    _labelBounds.add(origin & text.size);
    text.paint(canvas, origin);
  }

  @override
  bool shouldRepaint(covariant BetaArenaPainter oldDelegate) => true;
}
