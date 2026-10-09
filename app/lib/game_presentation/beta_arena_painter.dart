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
  const _Face(this.points, this.color, {this.unlit = false});
  final List<_V> points;
  final Color color;
  final bool unlit;
}

class _Projected {
  const _Projected(this.path, this.color, this.depth);
  final Path path;
  final Color color;
  final double depth;
}

/// Small software-projected 3D scene: real XYZ meshes, perspective, directional
/// shading and face sorting. Deliberately no new native renderer or GPU plugin.
/// Not a general 3D engine: no depth buffer, skeletal assets or vertical physics.
class BetaArenaPainter extends CustomPainter {
  BetaArenaPainter(this.run);
  final BetaSession run;
  static final _scenery = _buildScenery();
  late _V _camera, _right, _up, _forward;
  late Size _size;
  late double _focal;
  late double _horizon;

  static void _box(
    List<_Face> faces,
    _V center,
    _V size,
    Color color, {
    double yaw = 0,
  }) {
    final sx = size.x / 2, sy = size.y / 2, sz = size.z / 2;
    final c = math.cos(yaw), s = math.sin(yaw);
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
            ]
            .map((p) => center + _V(p.x * c + p.z * s, p.y, -p.x * s + p.z * c))
            .toList();
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
          _Face([
            _V(x.toDouble(), -.02, z.toDouble()),
            _V(x.toDouble(), -.02, z + 2.0),
            _V(x + 2.0, -.02, z + 2.0),
            _V(x + 2.0, -.02, z.toDouble()),
          ], color),
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
        ),
      );
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
    final scale = boss
        ? 1.65
        : enemy?.kind == BetaEnemyKind.brute
        ? 1.15
        : 1.0;
    final attacking = hero ? run.swordTime > 0 : enemy.windup > 0;
    final casting = hero && run.castTime > 0;
    final bob = moving
        ? math.sin(stride * 2).abs() * .055
        : math.sin(run.time * 2) * .018;
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
    if ((enemy?.flash ?? 0) > 0) {
      body = const Color(0xFFFFEBC3);
      skin = body;
    }
    _V world(double px, double py, double pz) => _V(
      x + (px * math.cos(angle) + pz * math.sin(angle)) * scale,
      (py + bob) * scale,
      z + (-px * math.sin(angle) + pz * math.cos(angle)) * scale,
    );
    void part(
      double px,
      double py,
      double pz,
      double w,
      double h,
      double d,
      Color color, {
      double twist = 0,
    }) => _box(
      faces,
      world(px, py, pz),
      _V(w * scale, h * scale, d * scale),
      color,
      yaw: angle + twist,
    );
    _disc(faces, x, z, .56 * scale, const Color(0x550E2726));
    final walk = moving ? math.sin(stride) * .19 : 0.0;
    part(-.18, .25, walk, .25, .5, .32, const Color(0xFF313F3C));
    part(.18, .25, -walk, .25, .5, .32, const Color(0xFF313F3C));
    part(0, .85, 0, .68, .74, .4, body);
    part(0, .56, 0, .71, .13, .45, const Color(0xFFC3A46A));
    if (hero) part(0, .91, -.27, .68, .83, .09, const Color(0xFF233F4A));
    part(0, 1.46, .02, .51, .48, .48, skin);
    part(0, 1.7, -.03, .61, .18, .55, body);
    part(-.13, 1.5, .27, .085, .085, .04, const Color(0xFF253331));
    part(.13, 1.5, .27, .085, .085, .04, const Color(0xFF253331));
    if (!hero) {
      part(-.38, 1.49, -.02, .35, .16, .19, skin, twist: -.35);
      part(.38, 1.49, -.02, .35, .16, .19, skin, twist: .35);
      part(-.13, 1.25, .29, .07, .18, .08, const Color(0xFFF0DDB1));
      part(.13, 1.25, .29, .07, .18, .08, const Color(0xFFF0DDB1));
    }
    final lift = casting
        ? .6
        : attacking
        ? .2
        : 0.0;
    part(-.47, .92 + lift, .03 - walk, .23, .53, .25, body);
    part(-.47, .65 + lift, .04 - walk, .24, .22, .27, skin);
    part(.47, .95 + lift, .08 + walk, .23, .5, .25, body);
    part(.47, .7 + lift, .12 + walk, .24, .22, .27, skin);
    if (boss) {
      part(-.47, 1.17, 0, .5, .42, .56, const Color(0xFFBBC09F));
      part(.47, 1.17, 0, .5, .42, .56, const Color(0xFFBBC09F));
      part(0, 1.01, .25, .22, .23, .1, const Color(0xFFDDB55A));
    }
    final swing = hero && attacking
        ? math.sin((.32 - run.swordTime) / .32 * math.pi) * 1.8 - .9
        : 0.0;
    final blade = hero
        ? betaElementColor(run.element)
        : const Color(0xFFCAC5A9);
    part(
      .51,
      .82 + lift,
      .5,
      .15,
      .14,
      .55,
      const Color(0xFF4C3830),
      twist: swing,
    );
    part(
      .51 + math.sin(swing) * .5,
      .86 + lift,
      .87,
      boss ? .5 : .12,
      boss ? .45 : .12,
      .95,
      blade,
      twist: swing,
    );
    if (casting) {
      final pulse = .22 + math.sin(run.time * 20) * .04;
      _box(
        faces,
        world(-.47, 1.6, .25),
        _V(pulse, pulse, pulse),
        blade,
        yaw: run.time * 5,
      );
    }
    if (hero && run.protection > 0) {
      _ring(faces, x, z, .85, const Color(0xFFDFC88B));
    }
    if (hero && run.dodgeTime > 0) {
      _ring(faces, x, z, .7, const Color(0xFFB4DBB2));
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
    _size = size;
    final wide = size.width > size.height;
    _focal = wide ? size.height * 1.1 : size.width * 1.35;
    _horizon = wide ? .57 : .47;
    final target = _V(run.x * .65, 0, run.z - 1.7);
    _camera = _V(target.x, 11, run.z + 13);
    _forward = (target - _camera).unit;
    _right = _forward.cross(const _V(0, 1, 0)).unit;
    _up = _right.cross(_forward);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF243F3D),
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
    for (final e in run.enemies.where((e) => e.alive)) {
      if (e.slow > 0) {
        _ring(faces, e.x, e.z, e.radius + .15, const Color(0xFF81BCCB));
      }
      if (e.burn > 0) {
        _box(
          faces,
          _V(e.x, e.boss ? 2.5 : 1.8, e.z),
          const _V(.16, .3, .16),
          const Color(0xFFE3A347),
          yaw: run.time * 3,
        );
      }
      if (e.windup > 0) {
        _disc(faces, e.aimX, e.aimZ, e.attackRadius, const Color(0x557F3629));
        _ring(
          faces,
          e.aimX,
          e.aimZ,
          e.attackRadius,
          const Color(0xFFE6A371),
          fraction: 1 - e.windup / e.preparation,
        );
      }
      _actor(
        faces,
        x: e.x,
        z: e.z,
        angle: e.angle,
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
      angle: run.angle,
      stride: run.time * 11,
      moving: run.moving,
    );
    for (final p in run.projectiles) {
      _box(
        faces,
        _V(p.x, .85 + math.sin(run.time * 16) * .05, p.z),
        const _V(.3, .3, .55),
        betaElementColor(p.element),
        yaw: math.atan2(p.dx, p.dz),
      );
      _box(
        faces,
        _V(p.x - p.dx * .45, .85, p.z - p.dz * .45),
        const _V(.13, .13, .2),
        betaElementColor(p.element),
      );
    }
    for (final fx in run.effects) {
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
      projected.add(_Projected(path, color, depth));
    }
    projected.sort((a, b) => b.depth.compareTo(a.depth));
    final paint = Paint()..isAntiAlias = true;
    for (final face in projected) {
      canvas.drawPath(face.path, paint..color = face.color);
    }
    for (final e in run.enemies.where((e) => e.alive && e.hp < e.maxHp)) {
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
    }
    for (final fx in run.effects.where((e) => e.text != null)) {
      final p = _project(_V(fx.x, 2.0 + (.65 - fx.life), fx.z));
      if (p == null) continue;
      final text = TextPainter(
        text: TextSpan(
          text: fx.text,
          style: TextStyle(
            color: fx.hurt ? const Color(0xFFFFBA9B) : const Color(0xFFFFE7A3),
            fontSize: 15,
            fontWeight: FontWeight.bold,
            shadows: const [
              Shadow(color: Color(0xFF1C312D), offset: Offset(1, 1)),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, p - Offset(text.width / 2, text.height));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant BetaArenaPainter oldDelegate) => true;
}
