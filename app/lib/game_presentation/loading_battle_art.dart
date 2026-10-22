part of 'beta_arena_painter.dart';

/// A deterministic eight-second vignette, not a playable/saved Beta session.
/// Only the existing actor meshes consume these transient poses. No engine ticks.
class LoadingBattlePainter extends CustomPainter {
  LoadingBattlePainter(this.clock) : super(repaint: clock);
  final Animation<double> clock;
  final _models = BetaArenaPainter(
    BetaSession(loadout: const BetaLoadout(sword: ShopUpgrade.spin)),
    outfit: HeroOutfit.angel,
  );
  final _goblins = List.generate(
    3,
    (_) => BetaEnemy(BetaEnemyKind.goblin, 0, 0),
  );
  List<_Face>? _ruins;
  static const gold = Color(0xFFEACF8A);

  void dispose() => _models.dispose();

  static double _ease(double t) {
    t = t.clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  static double _pulse(double t, double start, double duration) =>
      t >= start && t < start + duration
      ? math.sin((t - start) / duration * math.pi)
      : 0;

  static double _remaining(double t, double start, double duration) =>
      t >= start && t < start + duration ? duration - (t - start) : 0;

  List<_Face> _buildRuins() {
    final faces = <_Face>[];
    void block(_V p, _V size, Color c) =>
        BetaArenaPainter._box(faces, p, size, c);
    const stone = Color(0xFF777F74), dark = Color(0xFF4C5C53);
    // Compact stage instead of loading all six adventure regions.
    for (var row = 0; row < 5; row++) {
      for (var col = 0; col < 9; col++) {
        block(
          _V((col - 4) * 1.5, -.1, (row - 2) * 1.5),
          const _V(1.45, .16, 1.45),
          Color.lerp(
            const Color(0xFF637264),
            const Color(0xFF83907B),
            ((col * 13 + row * 7) % 5) / 5,
          )!,
        );
      }
    }
    for (var i = 0; i < faces.length; i++) {
      final face = faces[i];
      faces[i] = _Face(face.points, face.color, ground: true);
    }
    for (final x in [-5.2, 5.2]) {
      block(_V(x, 1.6, -3), const _V(.65, 3.2, .65), stone);
      block(_V(x, .15, -3), const _V(1.1, .3, 1.1), dark);
      block(_V(x, 3.2, -3), const _V(.95, .22, .95), gold);
      block(_V(x * .7, .18, -2.8), const _V(.8, .36, .6), stone);
    }
    for (var i = 0; i < 7; i++) {
      block(_V((i - 3) * 1.45, .38, -3.5), const _V(1.35, .76, .5), dark);
    }
    return faces;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    var t = clock.value * 8;
    // Brief contact holds, recovered within the same beat; never delay loading.
    for (final contact in [.78, 1.71, 5.0]) {
      final age = t - contact;
      if (age >= 0 && age < .12) {
        t = contact + (age < .035 ? 0 : (age - .035) * .12 / .085);
        break;
      }
    }
    final pose = _models.run;
    final roll = _ease((t - 3.05) / .42);
    final returnHome = _ease((t - 6.5) / 1.5);
    pose.x = -.4;
    pose.z = .35 + 1.7 * roll * (1 - returnHome);
    pose.angle =
        -math.pi / 2 +
        math.pi * _ease((t - 2.4) / .4) -
        (math.pi / 2 - .3) * _ease((t - 4) / .4) -
        (.3 + math.pi / 2) * returnHome;
    pose.swordTime = _remaining(t, 1.55, BetaSession.swordDuration);
    pose.dodgeTime = _remaining(t, 3.05, BetaSession.dodgeDuration);
    pose.castTime =
        _remaining(t, .55, BetaSession.castDuration) +
        _remaining(t, 4.65, BetaSession.castDuration);
    _models._clock = t;
    _models._size = size;
    _models._focal = math.min(size.width * 1.3, size.height * 1.65);
    _models._horizon = .53;
    _models._camera = const _V(0, 4.2, 10.8);
    _models._forward = (const _V(0, .9, 0) - _models._camera).unit;
    _models._right = _models._forward.cross(const _V(0, 1, 0)).unit;
    _models._up = _models._right.cross(_models._forward);

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF233B42), Color(0xFFB9A77C), Color(0xFF394A40)],
          stops: [0, .6, 1],
        ).createShader(Offset.zero & size),
    );
    final sun = Offset(size.width * .74, size.height * .27);
    canvas.drawCircle(
      sun,
      math.min(size.width, size.height) * .12,
      Paint()..color = const Color(0xFFDDC18C),
    );
    for (var layer = 0; layer < 2; layer++) {
      final ridge = Path()..moveTo(0, size.height);
      for (var i = 0; i <= 12; i++) {
        ridge.lineTo(
          size.width * i / 12,
          size.height * (.46 + layer * .13 + math.sin(i * 1.7 + layer) * .06),
        );
      }
      ridge
        ..lineTo(size.width, size.height)
        ..close();
      canvas.drawPath(
        ridge,
        Paint()
          ..color = layer == 0
              ? const Color(0xFF5C706B)
              : const Color(0xFF354F46),
      );
    }
    final impact =
        _pulse(t, .78, .18) + _pulse(t, 1.71, .2) + _pulse(t, 5, .25);
    canvas.translate(
      math.sin(t * 90) * impact * 1.4,
      math.cos(t * 75) * impact,
    );
    final faces = <_Face>[...(_ruins ??= _buildRuins())];
    // Torn cloth moves independently from the combat, with bounded geometry.
    for (final side in [-1.0, 1.0]) {
      final x = side * 5.2;
      faces.add(
        _Face(
          [
            _V(x, 3, -2.7),
            _V(x - side * .9, 3, -2.7),
            _V(x - side * .8, 1.45, -2.7 + math.sin(t * math.pi / 2) * .15),
            _V(x - side * .4, 1.7, -2.7),
            _V(x, 1.5, -2.7),
          ],
          const Color(0xFF704C49),
          doubleSided: true,
        ),
      );
    }
    for (var i = 0; i < 3; i++) {
      final e = _goblins[i];
      final attack = i == 0
          ? .15
          : i == 1
          ? 2.45
          : 4.1;
      final retreat = i == 0 ? 1.75 : attack + .8;
      final approach =
          _ease((t - attack + .5) / .5) * (1 - _ease((t - retreat) / .5));
      final blast = _ease((t - 5) / .35) * (1 - returnHome);
      final side = i == 1 ? 1.0 : -1.0;
      e.x = side * (2.65 - approach * 1.2 + blast * .9);
      if (i == 0) e.x -= _pulse(t, 1.71, .45) * .5;
      final baseZ = i == 2 ? -1.3 : .5;
      e.z = baseZ + (pose.z - baseZ) * approach * .6;
      e.angle = math.atan2(pose.x - e.x, pose.z - e.z);
      e.windup = _remaining(t, attack, e.preparation);
      e.recovery = _remaining(t, attack + e.preparation, e.recoveryDuration);
      e.flash =
          (i == 0 ? _pulse(t, .78, .22) + _pulse(t, 1.71, .22) : 0) * .22 +
          _pulse(t, 5.1, .3) * .22;
      _models._disc(faces, e.x, e.z, .55, const Color(0x44202D29));
      _models._actor(
        faces,
        x: e.x,
        z: e.z,
        angle: e.angle,
        stride: t * 9 + i,
        moving: approach > 0 || blast > 0,
        enemy: e,
      );
    }
    _models._disc(faces, pose.x, pose.z, .65, const Color(0x55202D29));
    _models._actor(
      faces,
      x: pose.x,
      z: pose.z,
      angle: pose.angle,
      stride: t * 7,
      moving: t > 6.5,
    );
    final burst = _ease((t - 5) / .9);
    if (t >= 5 && t < 5.9) {
      _models._ring(
        faces,
        pose.x,
        pose.z,
        .5 + burst * 5,
        gold.withValues(alpha: (1 - burst) * .8),
      );
      _models._ring(
        faces,
        pose.x,
        pose.z,
        .4 + burst * 4.6,
        const Color(0xFFFFF3DA).withValues(alpha: (1 - burst) * .65),
      );
    }
    final guard = _pulse(t, .55, .5);
    if (guard > 0) {
      for (var i = 0; i < 16; i++) {
        _V point(int step, double radius) {
          final a = step * math.pi / 8;
          return _V(
            pose.x - .65,
            1.05 + math.sin(a) * radius,
            pose.z + math.cos(a) * radius * .8,
          );
        }

        faces.add(
          _Face(
            [point(i, .55), point(i + 1, .55), point(i + 1, .5), point(i, .5)],
            gold.withValues(alpha: guard * .8),
            unlit: true,
            doubleSided: true,
          ),
        );
      }
    }
    _drawFaces(canvas, size, faces);
    void sparks(double start, _V origin) {
      final age = t - start;
      final point = _models._project(origin);
      if (age < 0 || age > .4 || point == null) return;
      final paint = Paint()
        ..color = gold.withValues(alpha: 1 - age / .4)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 9; i++) {
        final direction = Offset.fromDirection(i * 2.4, age * 70);
        canvas.drawLine(point + direction * .65, point + direction, paint);
      }
    }

    sparks(.78, const _V(-1, 1.1, .5));
    sparks(1.71, const _V(-1.3, 1, .5));
    if (t >= 4.65 && t < 5.35) {
      final center = _models._project(_V(pose.x, 1.2, pose.z + .6));
      if (center != null) {
        final p = (t - 4.65) / .7;
        final radius = 6 + math.sin(p * math.pi) * 17;
        canvas.drawCircle(
          center,
          radius,
          Paint()
            ..color = gold.withValues(alpha: .65 * math.sin(p * math.pi))
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
        for (var i = 0; i < 6; i++) {
          final a = t * 3 + i * math.pi / 3;
          canvas.drawCircle(
            center + Offset.fromDirection(a, radius),
            2,
            Paint()..color = const Color(0xFFFFF3DA),
          );
        }
      }
    }
    for (var i = 0; i < 12; i++) {
      final p = (clock.value + i / 12) % 1;
      canvas.drawCircle(
        Offset(size.width * (i * .618 % 1), size.height * (1 - p)),
        1 + i % 2,
        Paint()..color = gold.withValues(alpha: math.sin(p * math.pi) * .22),
      );
    }
    canvas.restore();
  }

  void _drawFaces(Canvas canvas, Size size, List<_Face> faces) {
    final projected = <_Projected>[];
    final light = const _V(-.5, 1, .6).unit;
    for (final face in faces) {
      var normal = (face.points[1] - face.points[0]).cross(
        face.points[2] - face.points[0],
      );
      if (normal.dot(normal) < .00000001) continue;
      if (!face.unlit && normal.dot(_models._camera - face.points[0]) <= 0) {
        if (!face.doubleSided) continue;
        normal = normal * -1;
      }
      final points = face.points.map(_models._project).toList();
      if (points.any((p) => p == null)) continue;
      final path = Path()..addPolygon(points.cast<Offset>(), true);
      if (!path.getBounds().overlaps(Offset.zero & size)) continue;
      final depth =
          face.points.fold<double>(
            0,
            (sum, p) => sum + (p - _models._camera).dot(_models._forward),
          ) /
          face.points.length;
      final shade = face.unlit
          ? 1.0
          : .58 + .42 * math.max(0, normal.unit.dot(light));
      final c = face.color;
      projected.add(
        _Projected(
          path,
          Color.fromARGB(
            (c.a * 255).round(),
            (c.r * 255 * shade).round(),
            (c.g * 255 * shade).round(),
            (c.b * 255 * shade).round(),
          ),
          depth,
          face.ground ? (face.unlit ? 1 : 0) : 2,
        ),
      );
    }
    projected.sort(
      (a, b) => a.layer == b.layer
          ? b.depth.compareTo(a.depth)
          : a.layer.compareTo(b.layer),
    );
    final paint = Paint();
    for (final face in projected) {
      canvas.drawPath(face.path, paint..color = face.color);
    }
  }

  @override
  bool shouldRepaint(covariant LoadingBattlePainter oldDelegate) =>
      clock != oldDelegate.clock;
}
