import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../game_domain/beta_session.dart';
import '../game_domain/cosmetics.dart';
import 'beta_health_feedback.dart';

part 'beta_spell_effects.dart';
part 'beta_world_art.dart';
part 'beta_wardrobe_art.dart';

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
    this.doubleSided = false,
  });
  final List<_V> points;
  final Color color;
  final bool unlit;
  final bool ground;
  final bool doubleSided;
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
  _RegionLook restored({required bool water}) => _RegionLook(
    Color.lerp(sky, const Color(0xFF8DC6D7), .7)!,
    Color.lerp(fog, const Color(0xFFDAE7D2), .65)!,
    Color.lerp(
      ground,
      water ? const Color(0xFF63AAA9) : const Color(0xFF78A96B),
      .5,
    )!,
    Color.lerp(path, const Color(0xFFD5C8A4), .5)!,
    Color.lerp(stone, const Color(0xFFDDD5BD), .45)!,
    const Color(0xFFE9CD91),
    const Color(0xFF84D6C6),
  );
  static const values = [
    _RegionLook(
      Color(0xFF304544),
      Color(0xFF839486),
      Color(0xFF415B4C),
      Color(0xFF9C9278),
      Color(0xFF8F9586),
      Color(0xFFD2BD93),
      Color(0xFFCEAE6E),
    ),
    _RegionLook(
      Color(0xFF344956),
      Color(0xFF94A6AA),
      Color(0xFF396C73),
      Color(0xFF889B9B),
      Color(0xFF758A91),
      Color(0xFFC6C9B6),
      Color(0xFF9AD0CB),
    ),
    _RegionLook(
      Color(0xFF373342),
      Color(0xFF8D869A),
      Color(0xFF504E61),
      Color(0xFF888194),
      Color(0xFF767283),
      Color(0xFFD0BDA1),
      Color(0xFFDEB675),
    ),
    _RegionLook(
      Color(0xFF506B70),
      Color(0xFFADC3B0),
      Color(0xFF5B7D59),
      Color(0xFFA6AA82),
      Color(0xFF9BA78D),
      Color(0xFFE2CBAC),
      Color(0xFFDCA9BD),
    ),
    _RegionLook(
      Color(0xFF41617A),
      Color(0xFF9CBAC3),
      Color(0xFF526E7A),
      Color(0xFFA8A9A2),
      Color(0xFF8198A6),
      Color(0xFFD6C5AA),
      Color(0xFF80D5DA),
    ),
    _RegionLook(
      Color(0xFF7E8AA2),
      Color(0xFFD1CDD1),
      Color(0xFF7C967C),
      Color(0xFFC3B998),
      Color(0xFFAAAEB7),
      Color(0xFFECD7A8),
      Color(0xFFDFC29A),
    ),
  ];
  static final restoredValues = [
    for (final region in BetaRegion.values)
      values[region.index].restored(
        water: region == BetaRegion.aqueduct || region == BetaRegion.forge,
      ),
  ];
}

/// Small software-projected 3D scene: real XYZ meshes, perspective, directional
/// shading and face sorting. Deliberately no new native renderer or GPU plugin.
/// Not a general 3D engine: no depth buffer, skeletal assets or vertical physics.
class BetaArenaPainter extends CustomPainter {
  BetaArenaPainter(
    this.run, {
    this.reduceMotion = false,
    this.outfit = HeroOutfit.traveler,
    this.wardrobePreview = false,
  }) : _cameraX = run.x * .8,
       _cameraZ = run.z,
       _heroAngle = run.angle,
       _heroHealth = BetaHealthFeedback(run.hp, run.maxHp) {
    for (final enemy in run.enemies) {
      _enemyHealth[enemy] = BetaHealthFeedback(enemy.hp, enemy.maxHp);
    }
  }
  final BetaSession run;
  final HeroOutfit outfit;
  final bool wardrobePreview;
  late BetaRegion _lastRegion = run.region;
  bool reduceMotion;
  double _cameraX, _cameraZ, _heroAngle;
  double _clock = 0;
  double _castRelease = 0;
  bool _wasCasting = false;
  static const _releaseDuration = .2;
  BetaElement _releaseElement = BetaElement.fire;
  BetaCombo? _releaseCombo;
  final _enemyAngles = <BetaEnemy, double>{};
  final BetaHealthFeedback _heroHealth;
  final _enemyHealth = <BetaEnemy, BetaHealthFeedback>{};
  double get heroHealthTrail => _heroHealth.trail;
  final _labelBounds = <Rect>[];
  final _labels = <(String, double, Color), TextPainter>{};
  static const labelCacheLimit = 64;
  @visibleForTesting
  int get cachedLabelCount => _labels.length;
  @visibleForTesting
  int get cachedSceneryFaceCount =>
      _scenery[(run.region, run.sceneryRestored)]?.length ?? 0;
  @visibleForTesting
  int get lastSpellFaceCount => _spellFaceCount;
  int _spellFaceCount = 0;

  void dispose() {
    for (final text in _labels.values) {
      text.dispose();
    }
    _labels.clear();
    _labelBounds.clear();
    _enemyAngles.clear();
    _enemyHealth.clear();
  }

  // Six regions × two restoration states; bounded, never rebuilt per frame.
  static final _scenery = <(BetaRegion, bool), List<_Face>>{};
  _RegionLook get _look => run.sceneryRestored
      ? _RegionLook.restoredValues[run.region.index]
      : _RegionLook.values[run.region.index];
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
    if (_wasCasting) {
      _releaseElement = run.element;
      _releaseCombo = run.castingCombo;
    }
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

  // Eighteen faces: tapered volumes with cut corners, kept low-poly for mobile.
  static void _hewn(
    List<_Face> faces,
    _V center,
    _V size,
    Color color, {
    double waist = .8,
    double crown = .78,
    double yaw = 0,
    _V Function(_V)? transform,
  }) {
    const outline = [
      (-.3, -.5),
      (.3, -.5),
      (.5, -.3),
      (.5, .3),
      (.3, .5),
      (-.3, .5),
      (-.5, .3),
      (-.5, -.3),
    ];
    final c = math.cos(yaw), s = math.sin(yaw);
    _V point((double, double) p, (double, double) ring) {
      final x = p.$1 * size.x * ring.$2, z = p.$2 * size.z * ring.$2;
      final result =
          center + _V(x * c + z * s, ring.$1 * size.y, -x * s + z * c);
      return transform?.call(result) ?? result;
    }

    final rings = [
      for (final ring in [(-.5, waist), (.18, 1.0), (.5, crown)])
        [for (final p in outline) point(p, ring)],
    ];
    for (var row = 0; row < 2; row++) {
      for (var i = 0; i < 8; i++) {
        final j = (i + 1) % 8;
        faces.add(
          _Face([
            rings[row][i],
            rings[row + 1][i],
            rings[row + 1][j],
            rings[row][j],
          ], color),
        );
      }
    }
    faces.add(_Face(rings.first, color));
    faces.add(_Face(rings.last.reversed.toList(), color));
  }

  // Split crystal: shared heraldry, not an illuminated gameplay marker.
  static void _crest(
    List<_Face> faces,
    _V center,
    double size,
    Color color, {
    _V Function(_V)? transform,
  }) {
    for (final side in [-1.0, 1.0]) {
      final points = [
        for (final p in [
          (.08, .65),
          (.55, 0.0),
          (.08, -.65),
          (.08, -.2),
          (.25, 0.0),
          (.08, .2),
        ])
          center + _V(side * p.$1 * size, p.$2 * size, 0),
      ];
      faces.add(
        _Face(
          [for (final p in points) transform?.call(p) ?? p],
          color,
          doubleSided: true,
        ),
      );
    }
  }

  static void _arch(
    List<_Face> faces,
    _V center,
    double width,
    double rise,
    double depth,
    Color color,
  ) {
    for (var i = 0; i < 7; i++) {
      final a = i * math.pi / 7, b = (i + 1) * math.pi / 7;
      _V point(double angle, bool outer, double z) =>
          center +
          _V(
            math.cos(angle) * (width / 2 + (outer ? .34 : 0)),
            math.sin(angle) * (rise + (outer ? .34 : 0)),
            z,
          );
      for (final z in [-depth / 2, depth / 2]) {
        faces.add(
          _Face(
            [
              point(a, false, z),
              point(b, false, z),
              point(b, true, z),
              point(a, true, z),
            ],
            Color.lerp(color, const Color(0xFF514B45), i.isEven ? .06 : .18)!,
            doubleSided: true,
          ),
        );
      }
      faces.add(
        _Face([
          point(a, false, -depth / 2),
          point(b, false, -depth / 2),
          point(b, false, depth / 2),
          point(a, false, depth / 2),
        ], color),
      );
      faces.add(
        _Face([
          point(a, true, -depth / 2),
          point(b, true, -depth / 2),
          point(b, true, depth / 2),
          point(a, true, depth / 2),
        ], color),
      );
    }
  }

  static void _banner(List<_Face> faces, _V top, Color cloth, Color trim) {
    _beam(
      faces,
      top + const _V(-.65, .08, 0),
      top + const _V(.65, .08, 0),
      .09,
      trim,
      (p) => p,
    );
    for (final side in [-1.0, 1.0]) {
      faces.add(
        _Face(
          [
            top + _V(side * .56, 0, 0),
            top + const _V(0, 0, .09),
            top + const _V(0, -1.6, .16),
            top + _V(side * .5, -1.35, 0),
          ],
          side < 0 ? cloth : Color.lerp(cloth, const Color(0xFF171E24), .2)!,
          doubleSided: true,
        ),
      );
    }
    _crest(faces, top + const _V(0, -.6, .17), .52, trim);
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

  static List<_Face> _buildScenery(BetaRegion region, bool restored) {
    final faces = <_Face>[];
    final look = restored
        ? _RegionLook.restoredValues[region.index]
        : _RegionLook.values[region.index];
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
    // Chipped paving is flat: decoration never introduces an invisible step.
    for (var row = 0; row < 14; row++) {
      for (var col = -1; col <= 1; col++) {
        final x = col * 1.65 + (row.isEven ? .12 : -.12), z = -9.5 + row * 1.45;
        final points = [
          (-.68, -.64),
          (.56, -.64),
          (.76, -.4),
          (.76, .5),
          (.53, .64),
          (-.76, .64),
          (-.76, -.45),
        ];
        faces.add(
          _Face(
            [for (final p in points.reversed) _V(x + p.$1, .002, z + p.$2)],
            Color.lerp(
              look.path,
              look.trim,
              ((row + col * 3).abs() % 5) * .055,
            )!,
            ground: true,
          ),
        );
      }
    }
    for (final o in region.obstacles) {
      // Keep the widest solid mesh inside the collision cylinder.
      final width = o.radius * 1.4;
      _box(faces, _V(o.x, .13, o.z), _V(width, .26, width), look.stone);
      _hewn(
        faces,
        _V(o.x, o.height / 2, o.z),
        _V(width * .7, o.height, width * .7),
        look.stone,
        waist: .95,
        crown: .92,
      );
      _box(faces, _V(o.x, o.height, o.z), _V(width, .22, width), look.trim);
      for (final level in [.3, .63]) {
        _box(
          faces,
          _V(o.x, o.height * level, o.z),
          _V(width * .73, .075, width * .73),
          Color.lerp(look.stone, look.trim, .28)!,
        );
      }
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
        _crest(
          faces,
          _V(o.x, o.height * .58, o.z + width * .36),
          width * .45,
          look.trim,
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
          _hewn(
            faces,
            _V(x, 4, z - 1),
            const _V(4.4, 3.3, 4.1),
            i.isEven ? const Color(0xFF3D5945) : const Color(0xFF6C7850),
            waist: .5,
            crown: .35,
            yaw: i * .4,
          );
        } else if (region == BetaRegion.aqueduct) {
          _box(
            faces,
            _V(side * 10.6, 1.9, z),
            const _V(.8, 3.8, .8),
            look.stone,
          );
          // Side arches run along Z; a local rotation keeps their opening clear.
          final arch = <_Face>[];
          _arch(arch, const _V(0, 0, 0), 3.2, 1.2, .85, look.trim);
          for (final face in arch) {
            faces.add(
              _Face(
                [
                  for (final p in face.points)
                    _V(side * 10.6 - p.z, 2.7 + p.y, z + 2 + p.x),
                ],
                face.color,
                doubleSided: face.doubleSided,
              ),
            );
          }
        } else if (region == BetaRegion.sanctum) {
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
    _arch(faces, const _V(0, 3.1, -10.9), 3.6, 1.4, .85, look.trim);
    _hewn(faces, const _V(0, 4.6, -10.9), const _V(.55, .75, 1), look.stone);
    _crest(faces, const _V(0, 4.6, -10.38), .45, look.trim);
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
    // Framing architecture and props remain beyond the playable perimeter.
    const bronze = Color(0xFFB99B67), timber = Color(0xFF66503D);
    final cloth = region == BetaRegion.sanctum
        ? const Color(0xFF795368)
        : const Color(0xFF315D68);
    for (final side in [-1.0, 1.0]) {
      final x = side * 3.45;
      _hewn(faces, _V(x, .7, -10.9), const _V(.6, 1.4, .6), look.stone);
      _hewn(
        faces,
        _V(x, 1.48, -10.9),
        const _V(.72, .3, .72),
        bronze,
        waist: .5,
        crown: 1,
      );
      _crown(faces, _V(x, 1.62, -10.9), .22, .55, const Color(0xFFE8B979));
      _box(faces, _V(side * 5.2, 2, -11.5), const _V(.12, 4, .12), timber);
      _banner(faces, _V(side * 5.2, 3.65, -11.35), cloth, bronze);
      if (region != BetaRegion.sanctum) {
        final tx = side * 7.5;
        _hewn(
          faces,
          _V(tx, 2.6, -17),
          const _V(2.7, 5.2, 2.7),
          look.stone,
          waist: 1,
          crown: .96,
        );
        _crown(
          faces,
          _V(tx, 5.2, -17),
          1.9,
          2.5,
          region == BetaRegion.roots
              ? const Color(0xFF626C59)
              : const Color(0xFF355C6E),
        );
        _box(faces, _V(tx, 3.8, -15.67), const _V(.35, 1.05, .035), look.sky);
        _crest(faces, _V(tx, 2, -15.62), .65, bronze);
      }
      // Short crates and broken timbers frame the edges, never the combat lane.
      _box(
        faces,
        _V(side * 9.4, .35, 4),
        const _V(.85, .7, .8),
        timber,
        yaw: side * .2,
      );
      for (final z in [3.75, 4.25]) {
        _box(faces, _V(side * 9.4, .72, z), const _V(.95, .07, .08), bronze);
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
      // Ruined chapel silhouette and inset glass, entirely behind the arena.
      for (final side in [-1.0, 1.0]) {
        _hewn(
          faces,
          _V(side * 4.2, 3.4, -17),
          const _V(1.7, 6.8, 1.8),
          look.stone,
          waist: 1,
          crown: .75,
        );
        _crown(faces, _V(side * 4.2, 6.8, -17), 1.1, 2.3, look.trim);
      }
      _arch(faces, const _V(0, 4.6, -17), 6.5, 3.2, .8, look.stone);
      _crest(faces, const _V(0, 6.3, -16.55), 2.1, const Color(0xFF7FA9A2));
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
    _addWorldArt(faces, region, look, restored);
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
    final hero = enemy == null;
    final scale = switch (enemy?.kind) {
      BetaEnemyKind.goblin => .9,
      BetaEnemyKind.brute => 1.15,
      BetaEnemyKind.darkElf => 1.05,
      BetaEnemyKind.guardian => 1.65,
      null => 1.0,
    };
    final casting = hero && run.castTime > 0;
    final dodging = hero && run.dodgeTime > 0 && run.phase != BetaPhase.lost;
    final dodgeProgress = dodging
        ? (1 - run.dodgeTime / BetaSession.dodgeDuration).clamp(0.0, 1.0)
        : 0.0;
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
        : math.sin(_clock * 2 + (hero ? 0 : x * .3 + z * .2)) * .018;
    double ease(double t) {
      t = t.clamp(0.0, 1.0);
      return t * t * (3 - 2 * t);
    }

    final tuck =
        ease(dodgeProgress / .16) * (1 - ease((dodgeProgress - .84) / .16));
    final tumble = ease((dodgeProgress - .16) / .68) * math.pi * 2;
    final rollAxis = _V(
      math.cos(run.dodgeDirection - angle),
      0,
      -math.sin(run.dodgeDirection - angle),
    );
    final tumbleCos = math.cos(tumble), tumbleSin = math.sin(tumble);
    final aerialRoll = hero && run.loadout.dodge == ShopUpgrade.somersault;
    final aerialHeight = dodging && aerialRoll
        ? math.sin(dodgeProgress * math.pi) * .75
        : 0.0;
    final attackProgress = hero && run.swordTime > 0
        ? 1 - run.swordTime / BetaSession.swordDuration
        : 0.0;
    final jumpHeight = hero && run.loadout.sword == ShopUpgrade.leap
        ? math.sin(attackProgress * math.pi) * .65
        : 0.0;
    // Complete the rotation at the actual contact frame, facing the target.
    final spinYaw =
        hero && run.swordTime > 0 && run.loadout.sword == ShopUpgrade.spin
        ? math.pi *
              2 *
              ease(
                (BetaSession.swordDuration - run.swordTime) /
                    BetaSession.swordContact,
              ) *
              run.swordSide
        : 0.0;

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
          lunge = -.12 * prepare + strike * .39;
        case BetaAttackShape.sweep:
          swing = -1.35 * prepare + strike * 2.7;
          lift =
              (enemy.kind == BetaEnemyKind.brute ? .38 : .2) *
              prepare *
              (1 - strike);
          lunge = -.1 * prepare + strike * .23;
        case BetaAttackShape.slam:
          lift = prepare * (1 - strike);
          lunge = strike * .22;
      }
    } else if (!hero && enemy.recovery > 0) {
      final recover = 1 - ease(1 - enemy.recovery / enemy.recoveryDuration);
      final sweeping = enemy.attackShape == BetaAttackShape.sweep;
      lunge = (sweeping ? .13 : .22) * recover;
      if (sweeping) swing = 1.35 * recover;
      if (enemy.attackShape == BetaAttackShape.thrust) thrust = .63 * recover;
    }
    final releasing = hero && run.swordTime <= 0 && !dodging && !dead;
    final charge = casting
        ? (1 - run.castTime / run.activeCastDuration).clamp(0.0, 1.0)
        : 0.0;
    final castPush = casting
        ? ease((charge - .65) / .35)
        : releasing
        ? ease(_castRelease / _releaseDuration)
        : 0.0;
    final castLift = casting
        ? ease((run.activeCastDuration - run.castTime) / .12)
        : releasing
        ? ease(_castRelease / _releaseDuration)
        : 0.0;
    final body = Color.lerp(
      Color(outfit.cloth),
      const Color(0xFFFFEBC3),
      recoil * .8,
    )!;
    final skin = Color.lerp(
      const Color(0xFFE3C89E),
      const Color(0xFFFFEBC3),
      recoil * .8,
    )!;
    final yaw = angle + swing * .16 + spinYaw;
    final collapse = enemy?.boss == true ? fall : 0.0;
    final tilt =
        -fall * (hero ? math.pi / 2 : .2) -
        recoil * .12 +
        lunge * .5 -
        castLift * .08 +
        castPush * .15;
    // Humanoids fall sideways so their weapons settle along the floor.
    final roll = enemy != null && !enemy.boss
        ? ease(fall) *
              math.pi /
              2 *
              (enemy.kind == BetaEnemyKind.darkElf ? -1 : 1)
        : 0.0;
    final ct = math.cos(tilt), st = math.sin(tilt);
    final cy = math.cos(yaw), sy = math.sin(yaw);
    final cr = math.cos(roll), sr = math.sin(roll);
    _V world(_V p) {
      if (dodging) {
        // Rotate the tucked body around the shoulder axis, not the camera.
        final local = _V(
          p.x,
          (p.y - .82) * (1 - tuck * .4),
          p.z * (1 - tuck * .25),
        );
        final rotated =
            local * tumbleCos +
            rollAxis.cross(local) * tumbleSin +
            rollAxis * (rollAxis.dot(local) * (1 - tumbleCos));
        return _V(
          x + (rotated.x * cy + rotated.z * sy),
          math.max(.03, .82 - tuck * .1 + rotated.y + aerialHeight),
          z + (-rotated.x * sy + rotated.z * cy),
        );
      }
      final px = p.x;
      final py = p.y * ct - p.z * st;
      final pz = p.y * st + p.z * ct + lunge;
      final sideX = px * cr - py * sr;
      final height =
          ((px * sr + py * cr) * (1 - collapse * .72) +
              bob +
              jumpHeight +
              (collapse > 0 ? 0 : fall * (hero ? .22 : .3))) *
          scale;
      return _V(
        x + (sideX * cy + pz * sy) * scale,
        !hero && dead ? math.max(.03, height) : height,
        z + (-sideX * sy + pz * cy) * scale,
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
    if (enemy != null) {
      _creatureMesh(
        faces,
        enemy,
        world,
        walk: walk,
        swing: swing,
        lift: lift,
        thrust: thrust,
        recoil: recoil,
        collapse: collapse,
      );
      return;
    }
    for (final side in [-1.0, 1.0]) {
      final foot = _V(
        side * (.18 + tuck * .06),
        .1 + math.max(0, walk * side) * .22 + tuck * .38,
        -walk * side + tuck * .06,
      );
      final knee = _V(
        side * .18,
        .32 + tuck * .38,
        -walk * side * .5 + .08 + tuck * .3,
      );
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
    final bronze = Color(outfit.trim);
    const leather = Color(0xFF655040);
    _hewn(
      faces,
      const _V(0, .85, 0),
      const _V(.68, .74, .44),
      body,
      waist: .7,
      transform: world,
    );
    part(0, .56, 0, .65, .12, .45, leather);
    part(0, .56, .24, .15, .13, .035, bronze);
    _hewn(
      faces,
      const _V(.35, .53, -.04),
      const _V(.22, .26, .25),
      leather,
      transform: world,
    );
    _beam(
      faces,
      const _V(-.26, 1.14, .22),
      const _V(.22, .61, .25),
      .065,
      leather,
      world,
      depth: .025,
    );
    _crest(faces, const _V(.14, 1.01, .229), .2, bronze, transform: world);
    final mantleColor = run.loadout.agility > 0
        ? const Color(0xFF3D8178)
        : Color(outfit.mantle);
    // Split travelling mantle, with folds that follow the existing walk/roll.
    final hem = -.38 - walk.abs() * .3;
    for (final side in [-1.0, 1.0]) {
      final a = _V(side * .34, 1.19, -.21), b = _V(side * .42, .38, hem);
      final fold = _V(0, .46, hem - .08);
      faces.add(
        _Face(
          [world(a), world(b), world(fold), world(const _V(0, 1.22, -.3))],
          side < 0
              ? mantleColor
              : Color.lerp(mantleColor, Color(outfit.cloth), .7)!,
          doubleSided: true,
        ),
      );
      _beam(faces, a, b, .025, bronze, world);
      faces.add(
        _Face(
          [
            world(_V(side * .28, .56, .23)),
            world(_V(side * .34, .28, .17)),
            world(_V(side * .06, .32, .26)),
            world(_V(side * .06, .56, .24)),
          ],
          body,
          doubleSided: true,
        ),
      );
    }
    _crest(
      faces,
      _V(0, .9, -.405 - walk.abs() * .16),
      .4,
      bronze,
      transform: world,
    );
    _hewn(
      faces,
      const _V(.39, 1.16, -.01),
      const _V(.32, .26, .43),
      Color(outfit.armor),
      transform: world,
    );
    _hewn(
      faces,
      const _V(0, 1.55, -.06),
      const _V(.68, .66, .64),
      body,
      waist: .94,
      crown: .35,
      transform: world,
    );
    _hewn(
      faces,
      const _V(0, 1.46, .14),
      const _V(.46, .45, .44),
      skin,
      crown: .86,
      transform: world,
    );
    const eyes = Color(0xFF253331);
    part(-.12, 1.5, .365, .075, .06, .025, eyes);
    part(.12, 1.5, .365, .075, .06, .025, eyes);
    part(0, 1.25, .16, .45, .13, .43, Color(outfit.mantle));
    _wardrobeArt(
      faces,
      outfit,
      run.loadout,
      world,
      flutter: reduceMotion ? 0 : math.sin(_clock * 3) * .09,
    );
    _V tucked(_V rest, _V folded) => rest + (folded - rest) * tuck;
    final hand = tucked(
      _V(
        .42 + math.sin(swing) * .3,
        .77 + lift * .65 - castLift * .14,
        .25 + math.cos(swing) * .17 + walk * .4 + thrust - castLift * .2,
      ),
      const _V(.28, 1.12, .26),
    );
    final leftHand = tucked(
      _V(
        -.45 - castLift * .15 + castPush * .1,
        .69 + castLift * .4 - castPush * .18,
        .16 + castLift * .19 + castPush * .3 - walk * .5,
      ),
      const _V(-.28, 1.12, .26),
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
    final blade = run.bladeCombo != null
        ? betaComboColor(run.bladeCombo!)
        : betaElementColor(run.bladeElement);
    final bladePitch = .12 + castLift * -.45;
    final direction = _V(
      math.sin(swing) * math.cos(bladePitch),
      math.sin(bladePitch),
      math.cos(swing) * math.cos(bladePitch),
    );
    final guard = tucked(hand + direction * .24, const _V(.26, 1.24, -.28));
    final tip = tucked(hand + direction * 1.49, const _V(-.25, .22, -.28));
    _beam(
      faces,
      tucked(hand - direction * .12, const _V(.32, 1.36, -.28)),
      guard,
      .13,
      const Color(0xFF4C3830),
      world,
    );
    final cross = _V(math.cos(swing), 0, -math.sin(swing)) * .2;
    final ridge = guard + const _V(0, .045, 0);
    faces.add(
      _Face([world(guard - cross * .4), world(tip), world(ridge)], blade),
    );
    faces.add(
      _Face([
        world(ridge),
        world(tip),
        world(guard + cross * .4),
      ], const Color(0xFFDFDFCC)),
    );
    faces.add(
      _Face([
        world(guard - cross * .4),
        world(guard + cross * .4),
        world(tip),
      ], blade),
    );
    _beam(
      faces,
      guard - cross,
      guard + cross,
      .09,
      const Color(0xFFC3A46A),
      world,
    );
    if (run.loadout.excalibur) {
      // Engraved golden crossguard and a luminous elemental blade ridge.
      _beam(
        faces,
        guard - cross * 1.5,
        guard + cross * 1.5,
        .12,
        const Color(0xFFE9C777),
        world,
      );
      _hewn(
        faces,
        guard,
        const _V(.17, .19, .17),
        blade,
        crown: 0,
        transform: world,
      );
      faces.add(
        _Face(
          [world(ridge), world(tip), world(ridge + const _V(.025, .025, 0))],
          Color.lerp(blade, Colors.white, .55)!,
          unlit: true,
          doubleSided: true,
        ),
      );
      if (run.blessingTime > 0) {
        for (var i = 1; i <= 3; i++) {
          final p = guard + (tip - guard) * (i / 4);
          _hewn(
            faces,
            p,
            const _V(.045, .09, .045),
            const Color(0xFFFFE5A2),
            crown: 0,
            transform: world,
          );
        }
      }
    }
    if (run.merlinTime > 0) {
      _merlinArt(faces, _V(x - 1.5, .08, z + .4), blade, run.merlinTime / 1.25);
    }
    if (run.wardTime > 0) {
      final strength = (run.wardTime / .7).clamp(0.0, 1.0);
      final wardColor = Color.lerp(
        const Color(0xFFADAD8B),
        const Color(0xFFB2DFCA),
        strength,
      )!;
      _crest(
        faces,
        const _V(0, .94, .41),
        .38 + strength * .1,
        wardColor,
        transform: world,
      );
      _ring(faces, x, z, .9, wardColor, fraction: strength);
    }
    if (run.burnTime > 0) {
      _ring(
        faces,
        x,
        z,
        .65,
        const Color(0xFFE49A57),
        fraction: (run.burnTime / 3).clamp(0.0, 1.0),
      );
    }
    if (run.curseTime > 0) {
      _ring(
        faces,
        x,
        z,
        .78,
        const Color(0xFFB79AD2),
        fraction: (run.curseTime / 4).clamp(0.0, 1.0),
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
      final orb = leftHand + const _V(0, .16, .12);
      final orbit = (1 - charge) * .28;
      _spellVisual(
        faces,
        world(orb + _V(-orbit, 0, 0)),
        run.element,
        combo: run.castingCombo,
        yaw: yaw,
        power: .45 + charge * .8,
      );
      // A previous sword blessing must not recolor the next spell's channel.
      final channelColor = run.castingCombo != null
          ? betaComboColor(run.castingCombo!)
          : betaElementColor(run.element);
      _ring(faces, x, z, .7 + charge * .2, channelColor, fraction: charge);
    } else if (releasing && _castRelease > 0) {
      // A short palm burst bridges gathering and projectile travel.
      _spellVisual(
        faces,
        world(leftHand + const _V(0, .05, .2)),
        _releaseElement,
        combo: _releaseCombo,
        yaw: yaw,
        power: castPush * .65,
      );
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
    if (dodging && tuck > .1) {
      for (var i = 0; i < 3; i++) {
        final distance = .25 + i * .2;
        _gem(
          faces,
          _V(
            x - math.sin(run.dodgeDirection) * distance,
            .08 + i * .025,
            z - math.cos(run.dodgeDirection) * distance,
          ),
          _V(.11, .06, .11) * tuck * (1 - i * .2),
          const Color(0xFFB6A787),
          angle,
        );
      }
    }
  }

  // Separate silhouettes share the existing action pose and world transform.
  // Detail stays bounded: no particles, textures or extra per-creature timers.
  void _creatureMesh(
    List<_Face> faces,
    BetaEnemy enemy,
    _V Function(_V) world, {
    required double walk,
    required double swing,
    required double lift,
    required double thrust,
    required double recoil,
    required double collapse,
  }) {
    const leather = Color(0xFF554232), iron = Color(0xFFB6C4BC);
    const bone = Color(0xFFE5D8AF), dark = Color(0xFF283236);
    Color tint(Color c) =>
        Color.lerp(c, const Color(0xFFFFEBC3), recoil * .75)!;
    void box(
      _V center,
      _V size,
      Color color, {
      double yaw = 0,
      double pitch = 0,
    }) => _box(
      faces,
      center,
      size,
      tint(color),
      yaw: yaw,
      pitch: pitch,
      transform: world,
    );
    void beam(_V a, _V b, double width, Color color) =>
        _beam(faces, a, b, width, tint(color), world);
    void triangle(_V a, _V b, _V c, Color color) =>
        faces.add(_Face([world(a), world(b), world(c)], tint(color)));
    void carved(
      _V center,
      _V size,
      Color color, {
      double waist = .8,
      double crown = .78,
    }) => _hewn(
      faces,
      center,
      size,
      tint(color),
      waist: waist,
      crown: crown,
      transform: world,
    );
    void ear(
      double side,
      double y,
      double z,
      Color color, {
      double length = .62,
    }) {
      final a = _V(side * .22, y - .1, z);
      final b = _V(side * .23, y + .12, z - .08);
      final tip = _V(side * length, y + .22, z - .06);
      final ridge = _V(side * .35, y + .03, z + .1);
      triangle(a, tip, ridge, color);
      triangle(ridge, tip, b, color);
      triangle(a, b, tip, color);
    }

    void arm(double side, _V shoulder, _V hand, double width, Color color) {
      final elbow = _V(
        shoulder.x + side * .13,
        (shoulder.y + hand.y) * .5,
        hand.z * .4 - .13,
      );
      beam(shoulder, elbow, width, color);
      beam(elbow, hand, width * .8, color);
      box(hand, _V(width, width * .9, width), color);
    }

    void blade(_V hand, double yaw, double length, Color color) {
      final direction = _V(math.sin(yaw), .06, math.cos(yaw));
      final cross = _V(math.cos(yaw), 0, -math.sin(yaw));
      final guard = hand + direction * .18;
      beam(hand - direction * .09, guard, .09, leather);
      beam(guard - cross * .14, guard + cross * .14, .065, bone);
      final tip = guard + direction * length;
      final ridge = guard + const _V(0, .065, 0);
      triangle(guard - cross * .09, tip, ridge, color);
      triangle(ridge, tip, guard + cross * .09, color);
      triangle(guard - cross * .09, guard + cross * .09, tip, color);
    }

    final contact = enemy.windup > 0
        ? (1 - enemy.windup / enemy.strikeDuration).clamp(0.0, 1.0)
        : (enemy.recovery / enemy.recoveryDuration).clamp(0.0, 1.0);
    final striking =
        enemy.alive &&
        ((enemy.windup > 0 && enemy.windup < enemy.strikeDuration) ||
            enemy.recovery > enemy.recoveryDuration - .08);
    void slash(_V hand, double yaw, double reach, double direction) {
      if (!striking) return;
      // Small ribbons follow the weapon; the ground marker owns hit detection.
      for (var i = 0; i < 3; i++) {
        final a = yaw - direction * i * .14;
        final b = a - direction * .14;
        _V point(double angle, double length) =>
            hand + _V(math.sin(angle) * length, .06, math.cos(angle) * length);
        faces.add(
          _Face(
            [
              world(point(a, reach)),
              world(point(b, reach)),
              world(point(b, reach * .86)),
              world(point(a, reach * .86)),
            ],
            const Color(0xFFE5D3AC).withValues(alpha: .8 - i * .2),
            unlit: true,
          ),
        );
      }
    }

    final goblin = enemy.kind == BetaEnemyKind.goblin;
    final elf = enemy.kind == BetaEnemyKind.darkElf;
    final stone = enemy.boss;
    final skin = switch (enemy.kind) {
      BetaEnemyKind.goblin => const Color(0xFF91AB59),
      BetaEnemyKind.brute => const Color(0xFFB09B80),
      BetaEnemyKind.darkElf => const Color(0xFF9490B0),
      BetaEnemyKind.guardian => const Color(0xFFA2A895),
    };
    final hip = goblin
        ? .45
        : elf
        ? .72
        : .6;
    final stance = elf
        ? .14
        : stone
        ? .25
        : .22;
    final legWidth = elf
        ? .16
        : stone
        ? .32
        : .25;
    for (final side in [-1.0, 1.0]) {
      final foot = _V(
        side * stance,
        .1 + math.max(0, walk * side) * .2,
        -walk * side + (goblin ? .1 : 0),
      );
      final knee = _V(
        side * (stance + (goblin ? .08 : 0)),
        hip * .55,
        -walk * side * .45 + (goblin ? .22 : .04),
      );
      beam(_V(side * stance, hip, -.04), knee, legWidth, skin);
      beam(knee, foot, legWidth * .85, stone ? dark : leather);
      box(
        foot + const _V(0, 0, .08),
        _V(legWidth * 1.15, .17, .34),
        stone ? skin : dark,
      );
    }

    switch (enemy.kind) {
      case BetaEnemyKind.goblin:
        carved(const _V(0, .7, -.05), const _V(.63, .53, .44), leather);
        box(
          const _V(0, .49, .05),
          const _V(.68, .13, .44),
          const Color(0xFFB2935D),
        );
        carved(
          const _V(0, 1.17, .17),
          const _V(.64, .48, .52),
          skin,
          crown: .86,
        );
        box(const _V(0, 1.08, .45), const _V(.25, .19, .21), skin);
        carved(
          const _V(0, 1.43, .1),
          const _V(.62, .19, .5),
          const Color(0xFF7B5544),
          crown: .4,
        );
        for (final side in [-1.0, 1.0]) {
          ear(side, 1.24, .19, skin);
          box(_V(side * .16, 1.24, .425), const _V(.12, .065, .035), dark);
          triangle(
            _V(side * .13, .98, .47),
            _V(side * .13, 1.11, .51),
            _V(side * .2, .98, .47),
            bone,
          );
        }
        // One battered shoulder plate and a small wooden buckler.
        box(
          const _V(-.34, .93, -.02),
          const _V(.31, .16, .37),
          const Color(0xFF8B7250),
          yaw: -.2,
        );
        final hand = _V(
          .35 - math.max(0, thrust) * .3,
          .67,
          .24 + thrust + walk * .2,
        );
        final offhand = _V(-.43, .54, .2 - walk * .3);
        arm(1, const _V(.3, .87, 0), hand, .21, skin);
        arm(-1, const _V(-.3, .87, 0), offhand, .21, skin);
        carved(offhand + const _V(0, 0, .12), const _V(.38, .42, .1), leather);
        box(offhand + const _V(0, 0, .18), const _V(.08, .08, .04), iron);
        blade(hand, -.12, 1.05, iron);
        if (striking) {
          beam(
            hand + const _V(0, .02, .5),
            hand + const _V(0, .02, 1.25),
            .045,
            bone,
          );
        }
      case BetaEnemyKind.brute:
        carved(const _V(0, .95, 0), const _V(1.02, .92, .65), skin, waist: .94);
        box(const _V(0, .64, .06), const _V(.94, .25, .61), leather);
        carved(const _V(0, 1.42, .17), const _V(.57, .5, .52), skin, crown: .7);
        box(const _V(0, 1.23, .4), const _V(.48, .21, .2), skin);
        carved(
          const _V(-.5, 1.23, 0),
          const _V(.48, .34, .65),
          const Color(0xFF697B78),
        );
        beam(const _V(-.38, 1.29, .28), const _V(.35, .67, .3), .1, leather);
        for (final side in [-1.0, 1.0]) {
          triangle(
            _V(side * .4, .68, .33),
            _V(side * .28, .32, .33),
            const _V(0, .6, .35),
            leather,
          );
          triangle(
            _V(side * .15, 1.17, .5),
            _V(side * .22, 1.47, .49),
            _V(side * .2, 1.2, .58),
            bone,
          );
        }
        for (final side in [-1.0, 1.0]) {
          box(_V(side * .14, 1.49, .421), const _V(.1, .07, .025), dark);
          triangle(
            _V(side * .15, 1.17, .5),
            _V(side * .22, 1.47, .49),
            _V(side * .25, 1.17, .49),
            bone,
          );
        }
        final hand = _V(
          .54 + math.sin(swing) * .36,
          .83 + lift,
          .3 + math.cos(swing) * .22,
        );
        arm(1, const _V(.43, 1.15, 0), hand, .32, skin);
        arm(
          -1,
          const _V(-.43, 1.15, 0),
          _V(-.61, .58, .15 - walk * .4),
          .32,
          skin,
        );
        final tip = hand + _V(math.sin(swing), .14, math.cos(swing)) * 1.05;
        beam(hand, tip, .16, leather);
        _hewn(
          faces,
          tip,
          const _V(.5, .58, .48),
          tint(const Color(0xFF70583E)),
          yaw: swing,
          crown: .9,
          transform: world,
        );
        box(
          tip + const _V(0, .15, 0),
          const _V(.51, .1, .48),
          iron,
          yaw: swing,
        );
        box(
          tip - const _V(0, .17, 0),
          const _V(.51, .1, .48),
          iron,
          yaw: swing,
        );
        slash(hand, swing, 1.3, 1);
      case BetaEnemyKind.darkElf:
        const armor = Color(0xFF443E58), hair = Color(0xFFD2D3C6);
        carved(const _V(0, 1.05, 0), const _V(.5, .67, .37), armor, waist: .64);
        box(
          const _V(0, .72, 0),
          const _V(.51, .11, .37),
          const Color(0xFFAD956A),
        );
        carved(const _V(0, 1.62, .02), const _V(.4, .45, .38), skin);
        carved(
          const _V(0, 1.84, -.02),
          const _V(.46, .17, .44),
          hair,
          crown: .5,
        );
        final hairTip = _V(.08, 1.03, -.29 - walk.abs() * .2);
        triangle(
          const _V(-.2, 1.8, -.2),
          hairTip,
          const _V(0, 1.77, -.27),
          hair,
        );
        triangle(
          const _V(0, 1.77, -.27),
          hairTip,
          const _V(.2, 1.8, -.2),
          bone,
        );
        _crest(
          faces,
          const _V(0, 1.16, .193),
          .2,
          tint(const Color(0xFFB5B7B9)),
          transform: world,
        );
        for (final side in [-1.0, 1.0]) {
          ear(side, 1.64, .02, skin, length: .51);
          carved(
            _V(side * .3, 1.3, 0),
            const _V(.22, .21, .35),
            const Color(0xFF82869A),
            crown: .4,
          );
          box(
            _V(side * .1, 1.66, .204),
            const _V(.065, .045, .025),
            const Color(0xFFE0C683),
          );
          final hem = _V(side * .31, .35, -.33 - walk.abs() * .35);
          triangle(_V(side * .24, 1.36, -.19), _V(0, 1.28, -.22), hem, armor);
          triangle(
            _V(0, 1.28, -.22),
            _V(0, .43, -.38),
            hem,
            const Color(0xFF343644),
          );
          final yaw = side > 0 ? swing : -swing * .8;
          final hand = _V(
            side * .4 + math.sin(yaw) * .22,
            .91 + lift * .4,
            .25 + math.cos(yaw) * .23 + walk * side * .25,
          );
          arm(side, _V(side * .27, 1.29, 0), hand, .16, armor);
          box(hand, const _V(.17, .16, .17), skin);
          blade(hand, yaw + side * .18, side > 0 ? 1.05 : .85, iron);
          slash(hand, yaw + side * .18, side > 0 ? 1.23 : 1.03, side);
        }
      case BetaEnemyKind.guardian:
        const joint = Color(0xFF3F4C49), rune = Color(0xFFD4B96F);
        carved(const _V(0, .97, 0), const _V(1.0, .82, .63), skin, waist: .7);
        box(const _V(0, .57, 0), const _V(.73, .13, .5), joint);
        carved(
          const _V(0, 1.55, .02),
          const _V(.57, .46, .49),
          skin,
          crown: .68,
        );
        box(const _V(0, 1.57, .264), const _V(.32, .075, .03), joint);
        box(const _V(0, 1.57, .285), const _V(.21, .04, .025), rune);
        box(const _V(0, 1.79, -.01), const _V(.29, .14, .45), joint);
        _crest(
          faces,
          const _V(0, 1.02, .325),
          .44,
          tint(rune),
          transform: world,
        );
        beam(const _V(-.3, 1.08, .3), const _V(-.17, .9, .305), .025, joint);
        beam(const _V(-.17, .9, .305), const _V(-.24, .73, .265), .025, joint);
        for (final side in [-1.0, 1.0]) {
          final shoulder = _V(side * (.58 + collapse * .25), 1.25, 0);
          carved(shoulder, const _V(.44, .42, .56), skin, crown: .7);
          box(
            shoulder + const _V(0, .19, -.04),
            const _V(.33, .07, .36),
            const Color(0xFF627157),
          );
          final hand = _V(
            side * (.6 + collapse * .35),
            .62 + lift * 1.2 - contact * .4,
            .42 + (1 - lift) * .35,
          );
          arm(side, shoulder, hand, .27, joint);
          carved(hand, const _V(.47, .43, .47), skin, crown: .9);
          for (var finger = 0; finger < 3; finger++) {
            box(
              hand + _V((finger - 1) * .13, -.04, .24),
              const _V(.11, .2, .13),
              skin,
            );
          }
        }
    }
  }

  double _creatureLabelHeight(BetaEnemyKind kind) => switch (kind) {
    BetaEnemyKind.goblin => 1.65,
    BetaEnemyKind.brute => 2.35,
    BetaEnemyKind.darkElf => 2.3,
    BetaEnemyKind.guardian => 3.4,
  };

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
          final a = (reduceMotion ? 0 : _clock * 9) + i * .6, b = a + .4;
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
          yaw: yaw + (reduceMotion ? 0 : _clock * 3),
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
    if (fx.life <= 0) return;
    // A blocked projectile fizzles locally; never display its damaging area.
    final blocked = fx.kind == BetaEffectKind.blocked;
    _spellVisual(
      faces,
      _V(fx.x, blocked ? .55 : .06, fx.z),
      fx.element,
      combo: fx.combo,
      power: blocked ? .3 : 1,
      impact: !blocked,
      progress: progress,
      opacity: (1 - progress) * (blocked ? .65 : 1),
    );
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
    _spellFaceCount = 0;
    if (size.isEmpty) return;
    _labelBounds.clear();
    _size = size;
    final wide = size.width > size.height;
    _focal = wide ? size.height * 1.1 : size.width * 1.35;
    _horizon = wide ? .57 : .47;
    final target = wardrobePreview
        ? _V(run.x, 1.15, run.z)
        : _V(_cameraX, 0, _cameraZ - 1.7);
    _camera = wardrobePreview
        ? _V(run.x + 3, 2.7, run.z + 5.5)
        : _V(target.x, 11, _cameraZ + 13);
    if (wardrobePreview) {
      _focal = math.min(size.width, size.height) * 1.85;
      _horizon = .52;
    }
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
      if (!wardrobePreview)
        ..._scenery.putIfAbsent((
          run.region,
          run.sceneryRestored,
        ), () => _buildScenery(run.region, run.sceneryRestored)),
    ];
    final gateColor = run.passageOpen ? _look.accent : _look.stone;
    final hint = run.puzzleActive ? run.puzzle.revealedHint : null;
    const hintColor = Color(0xFFF5D58B);
    if (!wardrobePreview) {
      _ring(faces, BetaRegion.gateX, BetaRegion.gateZ, 1.3, gateColor);
      if (!reduceMotion && run.nextEncounterIn > 0) {
        final origin = BetaAltar.all[run.puzzle.history.last.altar];
        final progress = 1 - run.nextEncounterIn / 2;
        _ring(
          faces,
          origin.x,
          origin.z,
          .8 + progress * 10,
          _look.accent.withValues(alpha: (1 - progress) * .4),
        );
      }
      if (run.remaining == 0) {
        for (var i = 0; i < BetaAltar.all.length; i++) {
          final altar = BetaAltar.all[i];
          final active = run.puzzle.history.any((s) => s.altar == i);
          final nearby = run.nearbyAltar == i;
          final indicated = hint?.altar == i;
          _ring(
            faces,
            altar.x,
            altar.z,
            .65,
            indicated
                ? hintColor
                : active
                ? const Color(0xFF9CE6C9)
                : _look.trim,
          );
          if (nearby || indicated) {
            _ring(
              faces,
              altar.x,
              altar.z,
              .83,
              indicated ? hintColor : _look.accent,
            );
          }
          // Floating echo is ethereal: ground seals remain fully walkable.
          _gem(
            faces,
            _V(altar.x, .45, altar.z),
            const _V(.14, .28, .14),
            nearby
                ? run.selectedCombo == null
                      ? betaElementColor(run.element)
                      : betaComboColor(run.selectedCombo!)
                : active
                ? const Color(0xFF9CE6C9)
                : _look.stone,
            reduceMotion ? 0 : _clock * .5,
          );
        }
      }
    }
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
    for (var i = 0; i < (wardrobePreview ? 0 : 4); i++) {
      final t = reduceMotion ? 0.0 : _clock;
      final x = (i.isEven ? -1 : 1) * (4.7 + i % 3 * .7);
      final z = -7 + i * 4.1;
      if (run.region == BetaRegion.aqueduct || run.region == BetaRegion.forge) {
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
      final target = hint == null ? null : BetaAltar.all[hint.altar];
      final direction = target == null
          ? run.aimDirection
          : math.atan2(target.x - run.x, target.z - run.z);
      final dx = math.sin(direction), dz = math.cos(direction);
      _V arrow(double forward, double side) => _V(
        run.x + dx * forward + dz * side,
        .03,
        run.z + dz * forward - dx * side,
      );
      faces.add(
        _Face(
          [arrow(1.02, 0), arrow(.73, -.13), arrow(.73, .13)],
          hint == null ? const Color(0xFFD5D6AB) : hintColor,
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
          _V(e.x, _creatureLabelHeight(e.kind) - .2, e.z),
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
      final age = (1.3 - p.life).clamp(0.0, 1.3);
      _spellVisual(
        faces,
        _V(p.x, p.combo == BetaCombo.firestorm ? .08 : .85, p.z),
        p.element,
        combo: p.combo,
        yaw: yaw,
      );
      if (p.combo != null) {
        continue; // Combo silhouettes carry their own trails.
      }
      for (var i = 1; i <= 3; i++) {
        final offset = i * .25;
        if (offset > age * 12) break; // Never trail behind the launch point.
        final center = _V(p.x - p.dx * offset, .83, p.z - p.dz * offset);
        final element = p.combo != null && i.isEven
            ? p.combo!.second
            : p.element;
        final color = betaElementColor(element);
        final size = 1 - i * .22;
        if (element == BetaElement.earth) {
          _box(
            faces,
            center,
            _V(.17, .13, .17) * size,
            color,
            yaw: yaw + age * 6 + i,
          );
        } else if (element == BetaElement.water ||
            element == BetaElement.wind) {
          _beam(
            faces,
            center,
            center +
                _V(
                  -p.dx * .18,
                  element == BetaElement.wind ? .1 : -.035,
                  -p.dz * .18,
                ),
            .075 * size,
            color,
            (p) => p,
          );
        } else {
          _gem(faces, center, _V(.12, .15, .18) * size, color, yaw);
        }
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
      var normal = (face.points[1] - face.points[0]).cross(
        face.points[2] - face.points[0],
      );
      if (normal.dot(normal) < .00000001) continue;
      if (!face.unlit && normal.dot(_camera - face.points[0]) <= 0) {
        if (!face.doubleSided) continue;
        normal = normal * -1;
      }
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
        _Projected(
          path,
          color,
          depth,
          face.ground
              ? (face.unlit
                    ? 2
                    : face.points.first.y > -.02
                    ? 1
                    : 0)
              : 3,
        ),
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
    if (!wardrobePreview && run.remaining == 0) {
      for (var i = 0; i < BetaAltar.all.length; i++) {
        final altar = BetaAltar.all[i];
        final indicated = hint?.altar == i;
        final echoes = run.puzzle.history
            .where((step) => step.altar == i)
            .length;
        final label =
            '${altar.label}${indicated
                ? ' · PISTA'
                : run.nearbyAltar == i
                ? ' · aqui'
                : echoes > 0
                ? ' · $echoes'
                : ''}';
        final p = _project(_V(altar.x, .9, altar.z));
        if (p != null) {
          _label(
            canvas,
            p,
            label,
            indicated ? hintColor : _look.trim,
            size: 12,
            badge: true,
          );
        }
      }
    }
    if (run.passageOpen) {
      final gate = _project(const _V(BetaRegion.gateX, .3, BetaRegion.gateZ));
      if (gate != null) {
        _label(
          canvas,
          gate,
          run.finalArea ? 'CONCLUIR EXPEDIÇÃO' : 'PASSAGEM ABERTA',
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
      final p = _project(_V(e.x, _creatureLabelHeight(e.kind), e.z));
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
