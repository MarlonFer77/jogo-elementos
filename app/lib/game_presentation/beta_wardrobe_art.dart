part of 'beta_arena_painter.dart';

/// Small procedural meshes share the actor's pose: no detached hats during rolls.
void _wardrobeArt(
  List<_Face> faces,
  HeroOutfit outfit,
  BetaLoadout loadout,
  _V Function(_V) world, {
  required double flutter,
}) {
  final gold = Color(outfit.trim);
  void box(_V p, _V size, Color color, {double pitch = 0}) =>
      BetaArenaPainter._box(
        faces,
        p,
        size,
        color,
        pitch: pitch,
        transform: world,
      );
  void plate(List<_V> points, Color color) =>
      faces.add(_Face(points.map(world).toList(), color, doubleSided: true));
  void beam(_V a, _V b, double size, Color color) =>
      BetaArenaPainter._beam(faces, a, b, size, color, world);

  if (outfit == HeroOutfit.angel) {
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6, b = (i + 1) * math.pi / 6;
      beam(
        _V(math.cos(a) * .3, 2.04, math.sin(a) * .3),
        _V(math.cos(b) * .3, 2.04, math.sin(b) * .3),
        .035,
        gold,
      );
    }
    for (final side in [-1.0, 1.0]) {
      final shoulder = _V(side * .25, 1.15, -.3);
      final tip = _V(side * 1.04, 1.83, -.4 + flutter);
      plate([
        shoulder,
        tip,
        _V(side * 1.12, .8, -.45),
        _V(side * .5, .63, -.36),
      ], const Color(0xFFD7DDE0));
      beam(shoulder, tip, .08, gold);
      for (var i = 0; i < 5; i++) {
        final px = side * (.48 + i * .15);
        plate([
          _V(px, 1.38 + i * .08, -.43 + flutter),
          _V(px + side * .16, 1.4 + i * .08, -.43 + flutter),
          _V(px + side * .24, .53 + i * .09, -.49),
          _V(px, .7 + i * .08, -.5),
        ], i.isEven ? const Color(0xFFFFF3DA) : const Color(0xFFE8E5D9));
      }
    }
  }
  if (outfit == HeroOutfit.demon) {
    for (final side in [-1.0, 1.0]) {
      beam(
        _V(side * .23, 1.75, 0),
        _V(side * .43, 2.02, -.04),
        .14,
        const Color(0xFFB3A189),
      );
      plate([
        _V(side * .36, 1.98, -.02),
        _V(side * .42, 2.23, .05),
        _V(side * .5, 1.98, -.04),
      ], const Color(0xFFE7CBA2));
      final root = _V(side * .24, 1.1, -.3);
      final top = _V(side * .9, 1.85, -.42 + flutter);
      final edge = _V(side * 1.22, .72, -.46);
      plate([root, top, edge], const Color(0xFF653849));
      plate([
        root,
        edge,
        _V(side * .72, .82, -.42),
        _V(side * .57, .4, -.38),
      ], const Color(0xFF3A3040));
      beam(root, top, .065, gold);
      beam(top, edge, .05, gold);
    }
    beam(const _V(0, .56, -.25), const _V(.24, .3, -.83), .075, gold);
    beam(const _V(.24, .3, -.83), const _V(.51, .58, -.95), .06, gold);
    plate([
      const _V(.4, .62, -.95),
      const _V(.7, .76, -.95),
      const _V(.59, .44, -.95),
    ], const Color(0xFFAC6356));
  }
  if (outfit == HeroOutfit.arthur) {
    box(const _V(0, 1.76, .02), const _V(.66, .1, .62), gold);
    for (final side in [-1.0, 0.0, 1.0]) {
      plate([
        _V(side * .23 - .08, 1.79, .34),
        _V(side * .23, 2.02 - side.abs() * .07, .34),
        _V(side * .23 + .08, 1.79, .34),
      ], gold);
    }
    box(const _V(0, .93, .24), const _V(.53, .49, .12), Color(outfit.armor));
    box(const _V(0, .6, .32), const _V(.24, .8, .04), Color(outfit.mantle));
    for (final side in [-1.0, 1.0]) {
      box(_V(side * .43, 1.16, 0), const _V(.3, .2, .48), Color(outfit.armor));
    }
    BetaArenaPainter._crest(
      faces,
      const _V(0, .96, .325),
      .22,
      gold,
      transform: world,
    );
  }
  if (loadout.agility > 0) {
    // Mercerus' silver chevrons remain identifiable over every outfit.
    for (final side in [-1.0, 1.0]) {
      beam(
        _V(0, 1.05, -.42),
        _V(side * .27, .8, -.46),
        .04,
        const Color(0xFFD0E0D5),
      );
      beam(
        _V(0, .82, -.45),
        _V(side * .25, .57, -.48),
        .04,
        const Color(0xFFD0E0D5),
      );
    }
  }
  if (loadout.perseus) {
    box(const _V(0, .91, .3), const _V(.6, .5, .13), const Color(0xFFADAD8B));
    BetaArenaPainter._crest(
      faces,
      const _V(0, .94, .38),
      .32,
      const Color(0xFF4D8576),
      transform: world,
    );
    for (final side in [-1.0, 1.0]) {
      beam(_V(side * .08, 1, .4), _V(side * .21, 1.12, .4), .04, gold);
      beam(_V(side * .21, 1.12, .4), _V(side * .24, .99, .4), .04, gold);
    }
  }
}

/// Merlin is a brief apparition, never a collider, ally AI or damage source.
void _merlinArt(List<_Face> faces, _V origin, Color element, double remaining) {
  final strength = math.min(1.0, remaining * 4);
  final robe = Color.lerp(const Color(0xFF6B8598), element, .25)!;
  _V world(_V p) => origin + p * (.85 + strength * .15);
  BetaArenaPainter._hewn(
    faces,
    const _V(0, .65, 0),
    const _V(.6, 1.2, .5),
    robe,
    waist: 1.35,
    crown: .65,
    transform: world,
  );
  BetaArenaPainter._hewn(
    faces,
    const _V(0, 1.4, 0),
    const _V(.35, .4, .34),
    const Color(0xFFDFD5BD),
    transform: world,
  );
  BetaArenaPainter._box(
    faces,
    const _V(0, 1.58, 0),
    const _V(.65, .045, .58),
    robe,
    transform: world,
  );
  for (var i = 0; i < 8; i++) {
    final a = i * math.pi / 4, b = (i + 1) * math.pi / 4;
    faces.add(
      _Face(
        [
          world(_V(math.cos(a) * .23, 1.61, math.sin(a) * .23)),
          world(const _V(-.12, 2.16, -.05)),
          world(_V(math.cos(b) * .23, 1.61, math.sin(b) * .23)),
        ],
        robe,
        doubleSided: true,
      ),
    );
  }
  for (final side in [-1.0, 1.0]) {
    BetaArenaPainter._box(
      faces,
      _V(side * .08, 1.45, .17),
      const _V(.045, .04, .025),
      const Color(0xFF22323A),
      transform: world,
    );
  }
  faces.add(
    _Face(
      [
        world(const _V(-.16, 1.35, .21)),
        world(const _V(.16, 1.35, .21)),
        world(const _V(0, .86, .25)),
      ],
      const Color(0xFFE8E9E2),
      doubleSided: true,
    ),
  );
  BetaArenaPainter._beam(
    faces,
    const _V(.25, 1.13, 0),
    const _V(.57, 1.35, .2),
    .14,
    robe,
    world,
  );
  BetaArenaPainter._beam(
    faces,
    const _V(.57, .06, .2),
    const _V(.57, 1.67, .2),
    .06,
    const Color(0xFFC7AE7F),
    world,
  );
  BetaArenaPainter._hewn(
    faces,
    const _V(.57, 1.76, .2),
    const _V(.21, .3, .21),
    element,
    crown: 0,
    transform: world,
  );
}
