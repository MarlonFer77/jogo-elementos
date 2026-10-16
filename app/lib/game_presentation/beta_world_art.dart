part of 'beta_arena_painter.dart';

/// Static, bounded fantasy landmarks. Solid decoration stays outside the arena.
/// Restoration changes art, never collisions or the device's graphics settings.
void _addWorldArt(
  List<_Face> faces,
  BetaRegion region,
  _RegionLook look,
  bool restored,
) {
  void box(_V p, _V size, Color color) =>
      BetaArenaPainter._box(faces, p, size, color);
  void crown(_V p, double radius, double height, Color color) =>
      BetaArenaPainter._crown(faces, p, radius, height, color);
  void crystal(_V p, _V size, Color color) => BetaArenaPainter._hewn(
    faces,
    p,
    size,
    color,
    waist: .3,
    crown: 0,
    yaw: .25,
  );
  final advanced = region.index >= BetaRegion.gardens.index;
  if (advanced) {
    // Layered floating ridges and pale terraces frame a broader fantasy world.
    for (final side in [-1.0, 1.0]) {
      for (var i = 0; i < 3; i++) {
        final x = side * (11 + i * 2.8), z = -4 - i * 7.0;
        BetaArenaPainter._hewn(
          faces,
          _V(x, .3 + i, z),
          const _V(4, 3, 4),
          look.stone,
          waist: 1,
          crown: .6,
        );
        box(_V(x, 1.9 + i, z), const _V(4.4, .25, 4.4), look.ground);
        if (region == BetaRegion.gardens) {
          box(
            _V(x, 3.1 + i, z),
            const _V(.4, 2.4, .4),
            const Color(0xFF75614B),
          );
          crown(
            _V(x, 3.8 + i, z),
            2.4,
            2.6,
            restored ? const Color(0xFFE9B9CF) : const Color(0xFF8C9B7B),
          );
          crown(_V(x - 1, 3.7 + i, z + .4), 1.5, 1.8, const Color(0xFFB6CAA1));
        } else if (region == BetaRegion.forge) {
          crystal(_V(x, 3.9 + i, z), const _V(1.4, 4, 1.4), look.accent);
          box(
            _V(x - 1.2, .3 + i, z + 2.25),
            const _V(.8, 3.5, .045),
            restored ? const Color(0xFF9FDFE1) : const Color(0xFF638B9C),
          );
        } else {
          box(_V(x, 3.5 + i, z), const _V(2.7, 3.2, 2.7), look.trim);
          crown(_V(x, 5.1 + i, z), 2.1, 2.2, const Color(0xFF487F92));
          BetaArenaPainter._crest(
            faces,
            _V(x, 3.5 + i, z + 1.36),
            .7,
            look.accent,
          );
        }
      }
    }
    if (region == BetaRegion.dawn) {
      // Twin spires and an open arch, not a wall hiding the playable exit.
      for (final x in [-4.5, 4.5]) {
        box(_V(x, 4, -20), const _V(2, 8, 2), look.stone);
        crown(_V(x, 8, -20), 1.6, 3.5, const Color(0xFF4F8894));
        crystal(_V(x, 11.8, -20), const _V(.25, .8, .25), look.trim);
      }
      BetaArenaPainter._arch(
        faces,
        const _V(0, 5.8, -20),
        7,
        3,
        .65,
        look.trim,
      );
      crystal(const _V(0, 9, -20), const _V(1, 2, .7), look.accent);
    }
  }
  if (!restored) return;
  // Every earlier area also gets a visible restoration, not just the new maps.
  for (final side in [-1.0, 1.0]) {
    for (var i = 0; i < 8; i++) {
      final x = side * (6.8 + (i % 2) * .7), z = -8 + i * 2.2;
      final color = region == BetaRegion.forge
          ? const Color(0xFFB0E4DD)
          : i.isEven
          ? const Color(0xFFE3C2CE)
          : const Color(0xFFF4DBA3);
      // Flat petals never imply a new collision obstacle.
      faces.add(
        _Face(
          [
            _V(x - .3, .025, z),
            _V(x, .025, z + .4),
            _V(x + .3, .025, z),
            _V(x, .025, z - .4),
          ],
          color,
          ground: true,
          doubleSided: true,
        ),
      );
      if (i.isEven) {
        box(_V(side * 9.5, 1.2, z), const _V(.16, 2.4, .16), look.trim);
        crystal(_V(side * 9.5, 2.55, z), const _V(.25, .45, .25), look.accent);
      }
    }
  }
  // Stained glass/echo rays reveal the recovered crest beyond the gate.
  for (var i = 0; i < 4; i++) {
    final x = (i - 1.5) * .65;
    box(
      _V(x, 3.4, -11.1),
      const _V(.42, 2.1, .03),
      betaElementColor(BetaElement.values[i]),
    );
  }
}
