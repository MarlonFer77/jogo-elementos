part of 'beta_arena_painter.dart';

/// Bounded procedural silhouettes. No timers, collision, random allocations of
/// persistent particles or gameplay state: lifetime belongs to BetaSession.
extension _BetaSpellEffects on BetaArenaPainter {
  void _spellVisual(
    List<_Face> faces,
    _V center,
    BetaElement element, {
    BetaCombo? combo,
    double yaw = 0,
    double power = 1,
    bool impact = false,
    double progress = 0,
    double opacity = 1,
    bool flight = false,
    double travel = 0,
  }) {
    if (power <= .001 || opacity <= .001) return;
    final before = faces.length;
    final phase = reduceMotion ? 0.0 : _clock * 5;
    progress = progress.clamp(0.0, 1.0);
    double ease(double t) {
      t = t.clamp(0.0, 1.0);
      return t * t * (3 - 2 * t);
    }

    // Fast arrival, then debris and vapour settle. Never pulse a blast twice.
    final growth = impact
        ? (.2 + .8 * ease(progress / .22)) *
              (1 - .45 * ease((progress - .4) / .6))
        : 1.0;
    final scale = power * (impact ? 1 : .48);
    _V world(_V p) =>
        center +
        _V(
              p.x * math.cos(yaw) + p.z * math.sin(yaw),
              p.y,
              -p.x * math.sin(yaw) + p.z * math.cos(yaw),
            ) *
            scale;
    Color tint(int value, [double alpha = 1]) =>
        Color(value).withValues(alpha: (opacity * alpha).clamp(0.0, 1.0));
    void gem(_V p, _V size, int color, [double alpha = 1]) =>
        _gem(faces, world(p), size * scale, tint(color, alpha), yaw + phase);
    void ribbon(List<_V> points, double width, Color color) {
      for (var i = 1; i < points.length; i++) {
        final a = points[i - 1], b = points[i];
        faces.add(
          _Face(
            [
              world(a),
              world(b),
              world(b + _V(0, width * (1 - i / points.length * .65), 0)),
              world(a + _V(0, width * (1 - (i - 1) / points.length * .65), 0)),
            ],
            color,
            unlit: true,
            doubleSided: true,
          ),
        );
      }
    }

    void hoop(
      double radius,
      double height,
      Color color, {
      double sweep = 6.283,
      double start = 0,
      double width = .08,
    }) {
      final points = List.generate(25, (i) {
        final a = start + i / 24 * sweep;
        return _V(math.cos(a) * radius, height, math.sin(a) * radius);
      });
      ribbon(points, width, color);
    }

    void flame(_V base, double height, double width, int color) {
      // Bent, tapered tongues with a bright inner face, not glowing spheres.
      final tip = base + _V(math.sin(phase + base.x * 3) * width, height, -.12);
      for (var i = 0; i < 3; i++) {
        final a = i * math.pi / 3;
        final side = _V(math.cos(a) * width, 0, math.sin(a) * width);
        faces.add(
          _Face(
            [
              world(base - side),
              world(base + side),
              world(base + side * .55 + _V(0, height * .5, 0)),
              world(tip),
              world(base - side * .3 + _V(0, height * .4, 0)),
            ],
            tint(color),
            unlit: true,
          ),
        );
      }
    }

    void cloud(_V p, double radius, int color, double alpha) {
      // Two low-poly lobes keep clouds readable without full-screen opacity.
      gem(p, _V(radius, radius * .65, radius), color, alpha);
      gem(
        p + _V(radius * .6, radius * .2, 0),
        _V(radius * .65, radius * .5, radius * .7),
        color,
        alpha * .8,
      );
    }

    void pool(double radius, int color) {
      for (var i = 0; i < 18; i++) {
        final a = i * math.pi / 9, b = (i + 1) * math.pi / 9;
        faces.add(
          _Face(
            [
              world(const _V(0, 0, 0)),
              world(_V(math.sin(a) * radius, 0, math.cos(a) * radius)),
              world(_V(math.sin(b) * radius, 0, math.cos(b) * radius)),
            ],
            tint(color, .65),
            unlit: true,
            ground: impact,
          ),
        );
      }
    }

    void cracks(double radius, int color) {
      for (var i = 0; i < 5; i++) {
        final a = i * math.pi * 2 / 5;
        final points = [
          for (var j = 0; j < 4; j++)
            _V(
              math.cos(a + (j.isOdd ? .13 : -.13)) * radius * j / 3,
              .018,
              math.sin(a + (j.isOdd ? .13 : -.13)) * radius * j / 3,
            ),
        ];
        for (var j = 1; j < points.length; j++) {
          final side = _V(-math.sin(a), 0, math.cos(a)) * .025;
          faces.add(
            _Face(
              [
                world(points[j - 1] - side),
                world(points[j] - side),
                world(points[j] + side),
                world(points[j - 1] + side),
              ],
              tint(color, .8),
              unlit: true,
              ground: true,
            ),
          );
        }
      }
    }

    switch (combo) {
      case BetaCombo.firestorm:
        // Narrow foot, broad crown, three rising helices and orbiting embers.
        final height = (impact ? 2.8 : 2.0) * growth;
        final radius = (impact ? combo!.radius * .68 : .8) * growth;
        // Translucent funnel joins the ribbons into a single rotating body.
        for (var level = 0; level < 5; level++) {
          for (var side = 0; side < 8; side++) {
            _V edge(int row, int column) {
              final t = row / 5;
              final a = column * math.pi / 4 + phase + t * .7;
              final r = .12 + t * radius;
              return world(_V(math.cos(a) * r, t * height, math.sin(a) * r));
            }

            faces.add(
              _Face(
                [
                  edge(level, side),
                  edge(level, side + 1),
                  edge(level + 1, side + 1),
                  edge(level + 1, side),
                ],
                tint(side.isEven ? 0xFFBD622F : 0xFFEDAE57, .18),
                unlit: true,
              ),
            );
          }
        }
        for (var strand = 0; strand < 3; strand++) {
          final points = List.generate(33, (i) {
            final t = i / 32;
            final a = phase * 2 + t * math.pi * 5 + strand * math.pi * 2 / 3;
            final r = (.12 + t * radius);
            return _V(math.cos(a) * r, t * height, math.sin(a) * r);
          });
          ribbon(
            points,
            .1 + growth * .13,
            tint(
              strand == 0
                  ? 0xFFFFDE8C
                  : strand == 1
                  ? 0xFFEC873B
                  : 0xFFB94D2D,
              .85,
            ),
          );
        }
        for (var i = 0; i < 6; i++) {
          final a = phase * 2 + i * math.pi / 3;
          final y = (i + 1) / 7 * height, r = .12 + (i + 1) / 7 * radius;
          flame(_V(math.cos(a) * r, y, math.sin(a) * r), .35, .09, 0xFFFFC864);
        }
        if (impact) {
          hoop(combo!.radius * math.sqrt(progress), .02, tint(0xFFEEA358, .5));
        }
      case BetaCombo.steam:
        // Pressurised geyser: bright water jets beneath rising white vapour.
        for (var i = 0; i < 5; i++) {
          final a = i * math.pi * 2 / 5;
          final height = (.9 + (i % 3) * .45) * growth;
          final sway =
              math.sin(phase * .6 + i) * (impact ? progress * .2 : .08);
          ribbon(
            [
              _V(math.cos(a) * .15, 0, math.sin(a) * .15),
              _V(math.cos(a) * .35, height * .65, math.sin(a) * .35),
              _V(math.cos(a) * .5, height, math.sin(a) * .5),
            ],
            .15,
            tint(0xFF9ED9D6, .8),
          );
          cloud(
            _V(
              math.cos(a) * .4 + sway,
              height + progress * .9,
              math.sin(a) * .4,
            ),
            .36 + progress * .28,
            0xFFE7E3CD,
            .6,
          );
        }
      case BetaCombo.eruption:
        final radius = impact ? combo!.radius : .85;
        if (impact) {
          pool(radius * .7 * growth, 0xFFA54B2C);
          cracks(radius * ease(progress / .4), 0xFFFFC269);
        }
        for (var i = 0; i < 7; i++) {
          final a = i * math.pi * 2 / 7;
          final r = radius * (impact ? .25 + progress * .6 : .55);
          final height = impact
              ? math.max(0.0, 4 * progress * (1 - progress)) *
                    (1.4 + i % 2 * .4)
              : .35;
          final point = _V(math.cos(a) * r, height, math.sin(a) * r);
          gem(point, const _V(.24, .32, .24), 0xFF68523F);
          flame(point + const _V(0, .05, 0), .5 * growth, .12, 0xFFF4AA4F);
        }
        flame(const _V(0, 0, 0), 2.2 * growth, .45 * growth, 0xFFD86830);
        flame(const _V(0, .05, 0), 1.5 * growth, .25 * growth, 0xFFFFDA81);
      case BetaCombo.mist:
        final radius = impact ? combo!.radius : 1.1;
        for (var i = 0; i < 6; i++) {
          final a = i * math.pi / 3 + phase * .1;
          final r = radius * (impact ? .2 + progress * .5 : .45);
          cloud(
            _V(
              math.cos(a) * r,
              .22 + (i % 2) * .15 + progress * .3,
              math.sin(a) * r,
            ),
            radius * .26 * growth,
            0xFFBBD8CB,
            .38,
          );
        }
        hoop(
          radius * (impact ? .2 + progress * .8 : .8),
          .15,
          tint(0xFFD6E6DB, .55),
          sweep: math.pi * 1.6,
          start: phase * .3,
        );
      case BetaCombo.mud:
        final radius = impact ? combo!.radius * (.25 + .75 * progress) : .7;
        pool(radius, 0xFF69533C);
        for (var i = 0; i < 2; i++) {
          hoop(
            radius * (1 - i * .35),
            .03 + i * .02,
            tint(0xFFA58C5C, .8),
            width: .04,
          );
        }
        for (var i = 0; i < 6; i++) {
          final a = i * math.pi / 3;
          // Heavy droplets fall earlier than water; the puddle stays flat.
          final y = impact
              ? math.max(0.0, 3 * progress * (1 - progress * 1.4))
              : .25;
          gem(
            _V(math.cos(a) * radius * .7, y, math.sin(a) * radius * .7),
            const _V(.19, .22, .15) * growth,
            0xFF927349,
          );
        }
      case BetaCombo.shards:
        // Sharp fragments fan outward; stone is angular, air is a thin crescent.
        for (var i = 0; i < 7; i++) {
          final a = i * math.pi * 2 / 7 + (impact ? .25 : phase);
          final r = impact ? .25 + progress * .8 : .6;
          gem(
            _V(
              math.cos(a) * r,
              impact
                  ? .15 + math.sin(progress * math.pi) * (.8 + i % 2 * .3)
                  : .6 + math.sin(a * 2) * .3,
              math.sin(a) * r,
            ),
            _V(.1, .32 * growth, .12),
            i.isEven ? 0xFFD0C8A4 : 0xFF8A9486,
          );
        }
        hoop(
          impact ? .3 + progress : .8,
          .6,
          tint(0xFFC7D8BC, .65),
          sweep: math.pi * 1.5,
          start: phase,
          width: .05,
        );
      case null:
        if (!impact) {
          _spellShape(faces, center, element, yaw: yaw, power: power * opacity);
        }
        switch (element) {
          case BetaElement.fire:
            for (var i = 0; i < 5; i++) {
              final a = i * math.pi * 2 / 5;
              final radius = impact ? progress * .7 : .2;
              flame(
                _V(math.cos(a) * radius, 0, math.sin(a) * radius),
                (1.1 + i % 2 * .5) * growth,
                .15,
                i.isEven ? 0xFFE88739 : 0xFFFFCD6C,
              );
            }
            if (impact) {
              for (var i = 0; i < 4; i++) {
                final a = i * math.pi / 2 + .3;
                gem(
                  _V(
                    math.cos(a) * progress,
                    progress * (1.8 - progress),
                    math.sin(a) * progress,
                  ),
                  const _V(.045, .1, .045),
                  0xFFFFD483,
                );
              }
            }
          case BetaElement.water:
            // Crown splash, falling droplets and two expanding water ripples.
            final radius = impact ? .2 + progress * .7 : .5;
            for (var i = 0; i < 8; i++) {
              final a = i * math.pi / 4, b = a + .35;
              final height = (impact ? math.sin(progress * math.pi) : .5) * .9;
              ribbon(
                [
                  _V(math.cos(a) * radius, .05, math.sin(a) * radius),
                  _V(math.cos(b) * radius, height, math.sin(b) * radius),
                ],
                .1,
                tint(0xFF83CAD4, .8),
              );
              gem(
                _V(math.cos(a) * radius, height + .2, math.sin(a) * radius),
                const _V(.055, .12, .055),
                0xFFE0EEE1,
              );
            }
            hoop(radius, .03, tint(0xFFA5DCD8, .7), width: .035);
            hoop(radius * .65, .04, tint(0xFF67B5C5, .7), width: .035);
          case BetaElement.wind:
            for (var i = 0; i < 3; i++) {
              final radius = impact ? .2 + progress * (1.8 - i * .2) : .6;
              hoop(
                radius,
                .2 + i * .24,
                tint(0xFFD0E4C7, .85 - i * .16),
                sweep: math.pi * 1.45,
                start: phase + i * 2,
                width: .09,
              );
            }
          case BetaElement.earth:
            if (impact) {
              cracks(1.05 * ease(progress / .35), 0xFF5C503C);
              for (var i = 0; i < 5; i++) {
                final a = i * math.pi * 2 / 5;
                gem(
                  _V(math.cos(a) * .55, .25 * growth, math.sin(a) * .55),
                  _V(.23, (.55 + i % 2 * .3) * growth, .23),
                  0xFFB19A72,
                );
              }
              hoop(.2 + progress * .7, .025, tint(0xFFC3AE86, .6), width: .04);
            }
        }
    }
    // Directional tails exist only in flight and never precede the launch point.
    // Replaces the old shared trail, rather than stacking particle emitters.
    if (flight && !reduceMotion && travel > 0) {
      final length = math.min(travel, 1.1) / scale;
      final solid =
          combo == BetaCombo.eruption ||
          combo == BetaCombo.mud ||
          combo == BetaCombo.shards ||
          (combo == null && element == BetaElement.earth);
      if (solid) {
        for (var i = 1; i <= 3; i++) {
          final t = i / 3, wobble = math.sin(phase + i) * .12;
          final color = combo == BetaCombo.eruption
              ? 0xFFEFA154
              : combo == BetaCombo.mud
              ? 0xFF927349
              : 0xFFC5BA99;
          gem(
            _V(wobble, -.12 * t, -length * t),
            _V(.12, combo == BetaCombo.shards ? .23 : .12, .18) * (1 - t * .65),
            color,
            1 - t * .55,
          );
        }
      } else {
        final hot = element == BetaElement.fire && combo != BetaCombo.steam;
        final color = hot
            ? 0xFFFFCB78
            : combo == BetaCombo.steam
            ? 0xFFE6E8D6
            : element == BetaElement.wind
            ? 0xFFD0E4C7
            : 0xFF8DD2D7;
        for (var strand = 0; strand < 2; strand++) {
          ribbon(
            [
              for (var i = 0; i <= 5; i++)
                _V(
                  math.sin(phase + i * .8 + strand * math.pi) * .18 * i / 5,
                  strand * .15 + (hot ? .15 : -.08) * i / 5,
                  -length * i / 5,
                ),
            ],
            hot ? .18 : .09,
            tint(color, .65 - strand * .15),
          );
        }
      }
    }
    _spellFaceCount += faces.length - before;
  }

  void _conjureVisual(
    List<_Face> faces,
    _V center,
    BetaElement element,
    BetaCombo? combo,
    double charge,
    double yaw,
  ) {
    if (combo == null || charge >= .45) {
      final gathered = combo == null ? charge : ((charge - .45) / .55);
      _spellVisual(
        faces,
        center,
        element,
        combo: combo,
        yaw: yaw,
        power: combo == null ? .35 + charge * .9 : .15 + gathered * 1.1,
      );
      return;
    }
    final before = faces.length;
    final remaining = 1 - charge / .45;
    final angle = (reduceMotion ? 0 : charge * math.pi * 2) + yaw;
    final orbit =
        _V(math.cos(angle), .25 * math.sin(angle), math.sin(angle)) *
        (.4 * remaining);
    final power = .12 + .45 * math.sin(remaining * math.pi / 2);
    _spellShape(faces, center + orbit, combo.first, yaw: yaw, power: power);
    _spellShape(faces, center - orbit, combo.second, yaw: yaw, power: power);
    _spellFaceCount += faces.length - before;
  }
}
