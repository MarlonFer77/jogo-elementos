import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../game_domain/beta_session.dart';
import 'beta_health_feedback.dart';

Color betaElementColor(BetaElement element) => switch (element) {
  BetaElement.fire => const Color(0xFFEAAF52),
  BetaElement.water => const Color(0xFF72BEC9),
  BetaElement.wind => const Color(0xFFB4DBB2),
  BetaElement.earth => const Color(0xFFD2B38A),
};

Color betaComboColor(BetaCombo combo) => Color.lerp(
  betaElementColor(combo.first),
  betaElementColor(combo.second),
  .5,
)!;

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

class _RegionLook {
  const _RegionLook(
    this.sky,
    this.fog,
    this.ground,
    this.path,
    this.stone,
    this.trim,
    this.accent,
  );
  final Color sky, fog, ground, path, stone, trim, accent;
  static const values = [
    _RegionLook(
      Color(0xFF263C36),
      Color(0xFF71836C),
      Color(0xFF52664B),
      Color(0xFF8B8465),
      Color(0xFF85896F),
      Color(0xFFC8B78C),
      Color(0xFFD6BD78),
    ),
    _RegionLook(
      Color(0xFF243C48),
      Color(0xFF687F84),
      Color(0xFF456C70),
      Color(0xFF798A84),
      Color(0xFF647B80),
      Color(0xFFA4B8AC),
      Color(0xFFA3CED0),
    ),
    _RegionLook(
      Color(0xFF302C3B),
      Color(0xFF716C7D),
      Color(0xFF55515F),
      Color(0xFF76707C),
      Color(0xFF666273),
      Color(0xFFB9AA94),
      Color(0xFFE0BB7D),
    ),
  ];
}

/// Small software-projected 3D scene: real XYZ meshes, perspective, directional
/// shading and face sorting. Deliberately no new native renderer or GPU plugin.
/// Not a general 3D engine: no depth buffer, skeletal assets or vertical physics.
class BetaArenaPainter extends CustomPainter {
  BetaArenaPainter(this.run, {this.reduceMotion = false})
    : _cameraX = run.x * .8,
      _cameraZ = run.z,
      _heroAngle = run.angle,
      _heroHealth = BetaHealthFeedback(run.hp, run.maxHp) {
    for (final enemy in run.enemies) {
      _enemyHealth[enemy] = BetaHealthFeedback(enemy.hp, enemy.maxHp);
    }
  }
  final BetaSession run;
  late BetaRegion _lastRegion = run.region;
  bool reduceMotion;
  double _cameraX, _cameraZ, _heroAngle;
  double _clock = 0;
  double _castRelease = 0;
  bool _wasCasting = false;
  static const _releaseDuration = .14;
  final _enemyAngles = <BetaEnemy, double>{};
  final BetaHealthFeedback _heroHealth;
  final _enemyHealth = <BetaEnemy, BetaHealthFeedback>{};
  double get heroHealthTrail => _heroHealth.trail;
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
    _enemyHealth.clear();
  }

  // Only three immutable scenes, built on first visit, never rebuilt per frame.
  static final _scenery = <BetaRegion, List<_Face>>{};
  _RegionLook get _look => _RegionLook.values[run.region.index];
  late _V _camera, _right, _up, _forward;
  late Size _size;
  late double _focal;
  late double _horizon;

  void advance(double elapsed) {
    if (!elapsed.isFinite || elapsed <= 0 || (!run.playing && !run.settling)) {
      return;
    }
    final dt = elapsed.clamp(0.0, .1);
    if (_lastRegion != run.region) {
      _lastRegion = run.region;
      _cameraX = run.x * .8;
      _cameraZ = run.z;
      _heroAngle = run.angle;
      _wasCasting = false;
      _castRelease = 0;
    }
    _heroHealth.advance(run.hp, run.maxHp, dt);
    _enemyHealth.removeWhere((enemy, _) => !run.enemies.contains(enemy));
    for (final enemy in run.enemies) {
      (_enemyHealth[enemy] ??= BetaHealthFeedback(
        enemy.hp,
        enemy.maxHp,
      )).advance(enemy.hp, enemy.maxHp, dt);
    }
    _clock += dt;
    _castRelease = math.max(0, _castRelease - dt);
    if (_wasCasting && run.castTime <= 0 && run.playing) {
      _castRelease = _releaseDuration;
    }
    // Follow-through is visual only and yields immediately to another action.
    if (run.castTime > 0 ||
        run.swordTime > 0 ||
        run.dodgeTime > 0 ||
        !run.playing) {
      _castRelease = 0;
    }
    _wasCasting = run.castTime > 0;
    final follow = 1 - math.exp(-6 * dt);
    final target = run.aimTarget;
    var lookX = run.moveX * .7, lookZ = run.moveZ;
    if (run.dodgeTime > 0) {
      lookX = math.sin(run.dodgeDirection) * .7;
      lookZ = math.cos(run.dodgeDirection);
    } else if (target != null &&
        BetaSession.distance(run.x, run.z, target.x, target.z) <= 6) {
      lookX = ((target.x - run.x) * .25).clamp(-1.2, 1.2);
      lookZ = ((target.z - run.z) * .25).clamp(-1.2, 1.2);
    }
    // Small world-space look-ahead: keep the hero visible, with no camera turns.
    if (reduceMotion) lookX = lookZ = 0;
    _cameraX += (run.x * .8 + lookX - _cameraX) * follow;
    _cameraZ += (run.z + lookZ - _cameraZ) * follow;
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

  static List<_Face> _buildScenery(BetaRegion region) {
    final faces = <_Face>[];
    final look = _RegionLook.values[region.index];
    void slab(
      double x,
      double z,
      double width,
      double depth,
      Color color, {
      double y = 0,
    }) {
      faces.add(
        _Face(
          [
            _V(x - width / 2, y, z - depth / 2),
            _V(x - width / 2, y, z + depth / 2),
            _V(x + width / 2, y, z + depth / 2),
            _V(x + width / 2, y, z - depth / 2),
          ],
          color,
          ground: true,
        ),
      );
    }

    for (var x = -9; x < 9; x += 2) {
      for (var z = -11; z < 11; z += 2) {
        final path = (x + 1).abs() <= 2;
        final tint = ((x * 17 + z * 31).abs() % 7) / 70;
        final color = Color.lerp(
          path ? look.path : look.ground,
          const Color(0xFF202B29),
          tint,
        )!;
        slab(x + 1.0, z + 1.0, 2, 2, color, y: -.02);
        if (!path && region == BetaRegion.roots && (x + z) % 4 == 0) {
          slab(x + 1.2, z + .7, 1.3, .6, const Color(0xFF60734B), y: -.01);
        }
      }
    }
    // Inlaid road rather than an oversized checkerboard; all overlays are flat.
    for (var i = 0; i < 10; i++) {
      final z = -9 + i * 2.0;
      slab(
        i.isEven ? -.65 : .55,
        z,
        1.6,
        1.25,
        Color.lerp(look.path, look.trim, .18)!,
        y: -.005,
      );
      slab(i.isEven ? .3 : -.4, z + .15, .04, .8, look.stone, y: 0);
    }
    for (final o in region.obstacles) {
      // Keep the widest solid mesh inside the collision cylinder.
      final width = o.radius * 1.4;
      _box(faces, _V(o.x, .13, o.z), _V(width, .26, width), look.stone);
      _box(
        faces,
        _V(o.x, o.height / 2, o.z),
        _V(width * .7, o.height, width * .7),
        look.stone,
      );
      _box(faces, _V(o.x, o.height, o.z), _V(width, .22, width), look.trim);
      if (region == BetaRegion.roots) {
        _box(
          faces,
          _V(o.x - width * .2, o.height * .45, o.z + width * .35),
          _V(.12, o.height * .85, .12),
          const Color(0xFF3D573B),
          yaw: .2,
        );
        slab(o.x, o.z, width * 2, width * 2, const Color(0xFF41583D));
      } else if (region == BetaRegion.sanctum) {
        _box(
          faces,
          _V(o.x, o.height * .65, o.z + width * .36),
          const _V(.12, .65, .035),
          look.accent,
        );
      }
    }
    // Perimeter geometry is outside the same bounds used by movement.
    for (final side in [-1.0, 1.0]) {
      for (var i = 0; i < 6; i++) {
        final z = -10 + i * 4.0;
        _box(faces, _V(side * 8.85, .3, z), const _V(.5, .6, 4), look.stone);
        _box(faces, _V(side * 8.85, .7, z), const _V(.6, 1.4, .65), look.trim);
        if (region == BetaRegion.roots) {
          final x = side * (11 + i % 2 * 1.8);
          _box(
            faces,
            _V(x, 1.8, z - 1),
            const _V(.55, 3.6, .55),
            const Color(0xFF514C39),
            yaw: i * .3,
          );
          _crown(
            faces,
            _V(x, 2.8, z - 1),
            2.2,
            2.6,
            i.isEven ? const Color(0xFF3D5945) : const Color(0xFF6C7850),
          );
        } else if (region == BetaRegion.aqueduct) {
          _box(
            faces,
            _V(side * 10.6, 1.9, z),
            const _V(.8, 3.8, .8),
            look.stone,
          );
          _box(
            faces,
            _V(side * 10.6, 3.9, z + 1.4),
            const _V(.85, .5, 2.8),
            look.trim,
          );
        } else {
          _crown(
            faces,
            _V(side * 11.5, 0, z),
            1.7,
            4 + i % 3 * 1.2,
            look.stone,
          );
        }
      }
    }
    for (final z in [-10.9, 10.9]) {
      _box(faces, _V(0, .23, z), const _V(17.5, .46, .5), look.stone);
    }
    // A distant skyline implies the ruined city beyond this playable route.
    for (var i = 0; i < 7; i++) {
      _crown(
        faces,
        _V(-24 + i * 8.0, -1, -31 - i % 2 * 4.0),
        7,
        2.5 + i % 3 * 1.2,
        Color.lerp(look.fog, look.sky, .5)!,
      );
    }
    for (final x in [-2.2, 2.2]) {
      _box(faces, _V(x, 1.6, -10.9), const _V(.8, 3.2, .8), look.stone);
      _box(faces, _V(x, 3.2, -10.9), const _V(1.1, .3, 1), look.trim);
    }
    if (region != BetaRegion.sanctum) {
      _box(faces, const _V(0, 3.5, -10.9), const _V(5.2, .5, 1), look.trim);
    }
    slab(0, BetaRegion.gateZ, 3.3, 3, look.stone, y: .002);
    // Landmarks stay behind the playable bounds, readable in portrait too.
    if (region == BetaRegion.roots) {
      for (final x in [-7.0, -4.5, 4.5, 7.0]) {
        _box(
          faces,
          _V(x, 2, -13),
          const _V(.55, 4, .55),
          const Color(0xFF514C39),
        );
        _crown(faces, _V(x, 2.3, -13), 2.2, 2.9, const Color(0xFF4B6844));
        _crown(faces, _V(x, 4, -13), 1.5, 2.1, const Color(0xFF7C8655));
      }
      for (final x in [-1.9, 1.9]) {
        _box(
          faces,
          _V(x, 1.7, -10.35),
          const _V(.13, 3.4, .13),
          const Color(0xFF476543),
          yaw: x * .1,
        );
      }
    }
    if (region == BetaRegion.aqueduct) {
      for (final x in [-7.0, -3.5, 3.5, 7.0]) {
        _box(faces, _V(x, 2.2, -14), const _V(.85, 4.4, 1.1), look.stone);
        _box(faces, _V(x, 3.7, -13.4), const _V(1.5, .35, .3), look.trim);
      }
      _box(faces, const _V(0, 4.5, -14), const _V(15.5, .7, 1.5), look.stone);
      _box(faces, const _V(0, 4.9, -14), const _V(15.5, .08, 1), look.accent);
      for (final x in [-6.0, 6.0]) {
        _box(
          faces,
          _V(x, 2.5, -12),
          const _V(.65, 4.7, .08),
          const Color(0xFF7CACB1),
        );
        _box(
          faces,
          _V(x - .13, 2.6, -11.94),
          const _V(.12, 4.3, .02),
          look.accent,
        );
      }
      // Shallow water is traversable; no invisible cliff or false bridge.
      for (final x in [-6.0, 6.0]) {
        for (var i = 0; i < 8; i++) {
          slab(x, -8 + i * 2.2, 2.6, .035, const Color(0xFF739B98), y: .008);
        }
      }
    } else if (region == BetaRegion.sanctum) {
      for (var step = 0; step < 3; step++) {
        _box(
          faces,
          _V(0, .2 + step * .35, -13),
          _V(6 - step * 1.1, .35, 2.8 - step * .3),
          look.stone,
        );
      }
      _box(faces, const _V(0, 3.2, -13), const _V(1.4, 4.5, 1.4), look.stone);
      _crown(faces, const _V(0, 5.45, -13), 1, 1.4, look.trim);
      for (var i = 0; i < 4; i++) {
        _box(
          faces,
          _V(0, 2.1 + i * .7, -12.28),
          const _V(.33, .33, .035),
          betaElementColor(BetaElement.values[i]),
          yaw: 0,
        );
      }
      for (final x in [-5.0, 5.0]) {
        _box(faces, _V(x, 2, -12.3), const _V(.25, 4, .25), look.trim);
        faces.add(
          _Face(
            [
              _V(x, 3.8, -12.1),
              _V(x + 1.2, 3.8, -12.1),
              _V(x + 1.2, 1.7, -12.1),
              _V(x + .6, 1.4, -12.1),
              _V(x, 1.7, -12.1),
            ],
            const Color(0xFF6C4D59),
            unlit: true,
          ),
        );
      }
      for (var i = 0; i < 8; i++) {
        final angle = i * math.pi / 4;
        slab(
          math.sin(angle) * 5.8,
          math.cos(angle) * 5.8 - 1,
          .28,
          .9,
          look.trim,
          y: .008,
        );
      }
    }
    return faces;
  }

  static void _crown(
    List<_Face> faces,
    _V base,
    double radius,
    double height,
    Color color,
  ) {
    final tip = base + _V(.2, height, -.15);
    for (var i = 0; i < 6; i++) {
      final a = i * math.pi / 3, b = (i + 1) * math.pi / 3;
      faces.add(
        _Face([
          base + _V(math.cos(a) * radius, 0, math.sin(a) * radius),
          tip,
          base + _V(math.cos(b) * radius, 0, math.sin(b) * radius),
        ], color),
      );
    }
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
    bool danger = false,
  }) {
    progress = progress.clamp(0.0, 1.0);
    final points = area.outline.map((p) => _V(p.x, .035, p.z)).toList();
    faces.add(
      _Face(
        points,
        (impact
                ? const Color(0xFFA88D60)
                : danger
                ? const Color(0xFFB64B36)
                : const Color(0xFFB48E51))
            .withValues(
              alpha:
                  (impact
                      ? .12
                      : danger
                      ? .25 + progress * .2
                      : .12 + progress * .1) *
                  opacity,
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
      final side = _V(-delta.z, 0, delta.x).unit * (danger ? .06 : .035);
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
      line(
        a,
        b,
        impact
            ? const Color(0xFFB69B6D)
            : danger
            ? const Color(0xFFE29572)
            : const Color(0xFFB69B6D),
      );
      if (!impact && remaining > 0 && lengths[i] > .00001) {
        line(
          a,
          a + (b - a) * (remaining / lengths[i]).clamp(0.0, 1.0),
          danger ? const Color(0xFFFFE1BE) : const Color(0xFFE9C982),
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
    final dodgeProgress = dodging
        ? (1 - run.dodgeTime / BetaSession.dodgeDuration).clamp(0.0, 1.0)
        : 0.0;
    final dodgeWeight = math.sin(dodgeProgress * math.pi);
    final dodgeSide = math.sin(run.dodgeDirection - angle) * dodgeWeight;
    final dodgeForward = math.cos(run.dodgeDirection - angle) * dodgeWeight;
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
    final releasing = hero && run.swordTime <= 0 && !dodging && !dead;
    final castLift = casting
        ? ease((run.activeCastDuration - run.castTime) / .12)
        : releasing
        ? ease(_castRelease / _releaseDuration)
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
    final tilt = -fall * math.pi / 2 - recoil * .12 + lunge * .5;
    final ct = math.cos(tilt), st = math.sin(tilt);
    final cy = math.cos(yaw), sy = math.sin(yaw);
    _V world(_V p) {
      // Lean into the committed dodge, keeping the feet near the ground.
      final px = p.x + p.y * dodgeSide * .4;
      final py = p.y * ct - p.z * st - p.y.clamp(0.0, .85) * dodgeWeight * .18;
      final pz = p.y * st + p.z * ct + lunge + p.y * dodgeForward * .45;
      return _V(
        x + (px * cy + pz * sy) * scale,
        (py + bob + fall * .22) * scale,
        z + (-px * sy + pz * cy) * scale,
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
        side * (.18 + dodgeSide.abs() * .07),
        .1 + math.max(0, walk * side) * .22,
        -walk * side + side * dodgeForward * .15,
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
      final charge = 1 - run.castTime / run.activeCastDuration;
      _spellShape(
        faces,
        world(leftHand + const _V(0, .05, .18)),
        run.castingCombo?.first ?? run.element,
        yaw: yaw,
        power: .35 + charge * .65,
      );
      if (run.castingCombo case final combo?) {
        _spellShape(
          faces,
          world(leftHand + const _V(.2, .22, .18)),
          combo.second,
          yaw: -yaw,
          power: .3 + charge * .45,
        );
      }
      _ring(faces, x, z, .7 + charge * .2, blade, fraction: charge);
    }
    if (hero && run.protection > 0) {
      _ring(
        faces,
        x,
        z,
        .85,
        const Color(0xFFDFC88B),
        fraction: (run.protection / 2).clamp(0.0, 1.0),
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
    final color = fx.combo == null
        ? betaElementColor(fx.element)
        : betaComboColor(fx.combo!);
    final scale = blocked ? .4 : 1.0;
    final radius =
        (fx.combo == null
            ? (fx.element == BetaElement.wind ? 2 : .9)
            : math.max(.9, fx.combo!.radius)) *
        scale;
    if (fx.combo != null ||
        fx.element == BetaElement.water ||
        fx.element == BetaElement.wind) {
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
      final orbit = a + (fx.combo == BetaCombo.firestorm ? progress * 5 : 0);
      final rise = math.sin(progress * math.pi);
      final height = switch (fx.combo) {
        BetaCombo.steam => .7 + progress * 1.5,
        BetaCombo.firestorm => .4 + (i % 3) * .3 + progress,
        BetaCombo.eruption => .12 + rise * 1.1,
        BetaCombo.mist => .15 + rise * .25,
        BetaCombo.mud => .08,
        BetaCombo.shards => .85 + rise * .4,
        null => .12 + rise * (fx.element == BetaElement.fire ? 1.4 : .6),
      };
      final point = _V(
        fx.x + math.sin(orbit) * spread,
        height,
        fx.z + math.cos(orbit) * spread,
      );
      final size =
          (.06 + (1 - progress) * .14) * scale * (fx.combo == null ? 1 : 1.35);
      final particleColor = fx.combo == null
          ? color
          : betaElementColor(i.isEven ? fx.combo!.first : fx.combo!.second);
      if (fx.element == BetaElement.earth ||
          fx.combo?.second == BetaElement.earth) {
        _box(
          faces,
          point,
          fx.combo == BetaCombo.mud
              ? _V(size * 1.6, .04, size * 1.6)
              : _V(size, size * 2, size),
          particleColor,
          yaw: a + progress,
        );
      } else {
        _gem(
          faces,
          point,
          _V(size, size * (fx.element == BetaElement.fire ? 2 : 1), size),
          particleColor,
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

  bool _threatensHero(BetaEnemy enemy) =>
      run.playing &&
      enemy.alive &&
      enemy.windup > 0 &&
      enemy.attackArea.contains(run.x, run.z) &&
      run.clearLine(enemy.x, enemy.z, run.x, run.z);

  void _contactImpact(Canvas canvas, BetaEffect fx) {
    final age = .65 - fx.life;
    if (age < 0 || age >= .22) return;
    final progress = age / .22;
    final center = _V(fx.x, 1, fx.z);
    final point = _project(center), edge = _project(center + _up * .55);
    if (point == null || edge == null) return;
    final radius = (point - edge).distance.clamp(4.0, 12.0);
    final color = fx.hurt
        ? const Color(0xFFFFBA9B)
        : betaElementColor(fx.element);
    final paint = Paint()
      ..color = Color.lerp(
        const Color(0xFFFFEAC4),
        color,
        .45 + progress * .55,
      )!.withValues(alpha: 1 - progress);
    // Composite above bodies so the short contact cue cannot hide inside a mesh.
    // It still uses only confirmed hits, never a missed swing or blocked attack.
    for (var i = 0; i < 5; i++) {
      final angle = i * math.pi * 2 / 5 + .35;
      final direction = Offset(math.cos(angle), math.sin(angle));
      final side = Offset(-direction.dy, direction.dx);
      final inner = point + direction * radius * (.15 + progress * .7);
      final tip = point + direction * radius * (1 + progress * .7);
      final width = radius * .18 * (1 - progress);
      canvas.drawPath(
        Path()
          ..addPolygon([inner - side * width, tip, inner + side * width], true),
        paint,
      );
    }
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
    canvas.drawRect(Offset.zero & size, Paint()..color = _look.sky);
    final shake = reduceMotion ? 0.0 : run.impactTime / .18;
    canvas.translate(
      math.sin(_clock * 85) * shake * 1.8,
      math.cos(_clock * 73) * shake * 1.2,
    );
    final faces = <_Face>[
      ..._scenery.putIfAbsent(run.region, () => _buildScenery(run.region)),
    ];
    final gateColor = run.passageOpen ? _look.accent : _look.stone;
    _ring(faces, BetaRegion.gateX, BetaRegion.gateZ, 1.3, gateColor);
    if (run.passageProgress > 0) {
      _ring(
        faces,
        BetaRegion.gateX,
        BetaRegion.gateZ,
        1.05,
        _look.trim,
        fraction: run.passageProgress,
      );
    }
    // Small environmental accents, fixed count; decorative motion can be reduced.
    for (var i = 0; i < 4; i++) {
      final t = reduceMotion ? 0.0 : _clock;
      final x = (i.isEven ? -1 : 1) * (4.7 + i % 3 * .7);
      final z = -7 + i * 4.1;
      if (run.region == BetaRegion.aqueduct) {
        _ring(
          faces,
          x,
          z,
          .15 + ((t * .2 + i * .17) % 1) * .45,
          _look.accent.withValues(alpha: .2),
        );
      } else {
        _box(
          faces,
          _V(
            x + math.sin(t * .4 + i) * .2,
            .7 + (i % 3) * .35 + math.sin(t + i) * .12,
            z,
          ),
          const _V(.045, .045, .045),
          _look.accent,
        );
      }
    }
    final aim = run.aimTarget;
    final inDanger = run.enemies.any(_threatensHero);
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
        _attackArea(
          faces,
          e.attackArea,
          1 - e.windup / e.preparation,
          danger: _threatensHero(e),
        );
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
    _ring(
      faces,
      run.x,
      run.z,
      .65,
      inDanger ? const Color(0xFFFFC497) : const Color(0xFFC9CE9C),
    );
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
      if (p.combo case final combo?) {
        _spellShape(
          faces,
          _V(p.x + .15, 1.05, p.z),
          combo.second,
          yaw: -yaw,
          power: .65,
        );
      }
      for (var i = 1; i <= 3; i++) {
        final offset = i * .25;
        _gem(
          faces,
          _V(p.x - p.dx * offset, .83, p.z - p.dz * offset),
          _V(.12, .1, .17) * (1 - i * .22),
          p.combo == null
              ? betaElementColor(p.element)
              : betaComboColor(p.combo!),
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
          _look.fog,
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
    if (run.passageOpen) {
      final gate = _project(const _V(BetaRegion.gateX, .3, BetaRegion.gateZ));
      if (gate != null) {
        _label(
          canvas,
          gate,
          'PASSAGEM ABERTA',
          _look.accent,
          size: 10,
          badge: true,
        );
      }
    }
    for (final fx in run.effects) {
      if (fx.kind == BetaEffectKind.impact &&
          fx.area == null &&
          fx.text != null) {
        _contactImpact(canvas, fx);
      }
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
      final width = e.boss ? 62.0 : 34.0;
      final current = (e.hp / e.maxHp).clamp(0.0, 1.0);
      final trail = math.max(current, _enemyHealth[e]?.trail ?? current);
      final left = p.dx - width / 2;
      canvas.drawRect(
        Rect.fromLTWH(left, p.dy, width, 5),
        Paint()..color = const Color(0xFF213A36),
      );
      canvas.drawRect(
        Rect.fromLTWH(left + 1, p.dy + 1, (width - 2) * trail, 3),
        Paint()..color = const Color(0xFFF2DFC0),
      );
      canvas.drawRect(
        Rect.fromLTWH(left + 1, p.dy + 1, (width - 2) * current, 3),
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
    if (run.playing && (inDanger || run.protection > 0)) {
      final p = _project(_V(run.x, inDanger ? .02 : 2.15, run.z));
      if (p != null) {
        _label(
          canvas,
          inDanger ? p + const Offset(0, 26) : p,
          inDanger ? 'SAIA DA ÁREA' : 'Proteção ${run.protection.ceil()}s',
          inDanger ? const Color(0xFFFFD7B3) : const Color(0xFFE7CE94),
          size: 10,
          badge: inDanger,
        );
      }
    }
    for (final fx in run.effects.where((e) => e.text != null)) {
      final age = (.65 - fx.life).clamp(0.0, .65);
      final pop = (1 - age / .12).clamp(0.0, 1.0);
      final p = _project(_V(fx.x, 2.0 + age * .8, fx.z));
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
        scale: reduceMotion ? 1 : 1 + pop * .2,
        opacity: (fx.life / .18).clamp(0.0, 1.0),
      );
    }
    if (run.arrivalTime > 0 && !reduceMotion) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..color = _look.sky.withValues(
            alpha: (run.arrivalTime / BetaSession.arrivalDuration).clamp(
              0.0,
              1.0,
            ),
          ),
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
    bool badge = false,
    double scale = 1,
    double opacity = 1,
  }) {
    if (opacity <= 0) return;
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
    // Animate the cached layout, not its style: no new cache entry per frame.
    final layout = text.size * scale;
    var origin = p - Offset(layout.width / 2, layout.height);
    final padding = badge ? 4.0 : 0.0;
    for (var attempt = 0; attempt < _labelBounds.length; attempt++) {
      final overlaps = _labelBounds.where(
        (rect) => rect.inflate(2).overlaps((origin & layout).inflate(padding)),
      );
      if (overlaps.isEmpty) break;
      final top = overlaps.map((rect) => rect.top).reduce(math.min);
      origin = Offset(origin.dx, top - layout.height - padding - 3);
    }
    final bounds = (origin & layout).inflate(padding);
    _labelBounds.add(bounds);
    if (opacity < 1) {
      canvas.saveLayer(
        bounds.inflate(2),
        Paint()..color = Colors.white.withValues(alpha: opacity),
      );
    }
    if (badge) {
      canvas.drawRect(bounds, Paint()..color = const Color(0xF22C3932));
      canvas.drawRect(
        bounds,
        Paint()
          ..color = const Color(0xFFE29572)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.scale(scale);
    text.paint(canvas, Offset.zero);
    canvas.restore();
    if (opacity < 1) canvas.restore();
  }

  @override
  bool shouldRepaint(covariant BetaArenaPainter oldDelegate) => true;
}
