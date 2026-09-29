import 'dart:math' as math;
import 'dart:ui';
import '../game_domain/combatant_appearance.dart';
import 'element_visuals.dart';

/// Original, code-native pixel art. All creatures face right in a 32x40 grid.
/// The battle component supplies motion/poses; this painter knows no rules.
class CreatureArt {
  CreatureArt(
    this.canvas,
    this.time,
    this.charge,
    this.strike,
    this.striding,
    this.element,
  );
  final Canvas canvas;
  final double time, charge, strike;
  final bool striding;
  final String? element;
  static const ink = Color(0xFF202630);
  static const ivory = Color(0xFFF4E3BC);
  static const gold = Color(0xFFE1B656);
  final Paint _paint = Paint()..isAntiAlias = false;

  double get sway => math.sin(time * (striding ? 22 : 4));
  Color get magic => element == null ? gold : elementColor(element!);

  static void draw(
    Canvas canvas,
    CombatantAppearance appearance, {
    double time = 0,
    double charge = 0,
    double strike = 0,
    bool striding = false,
    String? element,
  }) {
    canvas.save();
    canvas.scale(2);
    final art = CreatureArt(canvas, time, charge, strike, striding, element);
    switch (appearance) {
      case CombatantAppearance.emberGoblin:
        art._goblin();
      case CombatantAppearance.frostElf:
        art._elf(true);
      case CombatantAppearance.darkElf:
        art._elf(false);
      case CombatantAppearance.swampGolem:
        art._golem();
      case CombatantAppearance.sunScarab:
        art._scarab();
      case CombatantAppearance.stormHarpy:
        art._harpy();
      case CombatantAppearance.ancientEnt:
        art._ent();
      case CombatantAppearance.thunderTroll:
        art._troll();
      case CombatantAppearance.plagueSpider:
        art._spider();
      case CombatantAppearance.ruinDrake:
        art._drake();
      case CombatantAppearance.adventurer:
        break;
    }
    canvas.restore();
  }

  void r(double x, double y, double w, double h, Color c) {
    _paint
      ..color = c
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(x.roundToDouble(), y.roundToDouble(), w, h),
      _paint,
    );
  }

  void box(double x, double y, double w, double h, Color c) {
    r(x, y, w, h, ink);
    r(x + 1, y + 1, w - 2, h - 2, c);
  }

  void shape(List<Offset> points, Color c) {
    final path = Path()..addPolygon(points, true);
    _paint
      ..color = c
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, _paint);
    _paint
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawPath(path, _paint);
  }

  void limb(Offset a, Offset b, Offset c, Color color, double width) {
    final path = Path()
      ..moveTo(a.dx, a.dy)
      ..lineTo(b.dx.roundToDouble(), b.dy.roundToDouble())
      ..lineTo(c.dx.roundToDouble(), c.dy.roundToDouble());
    _paint
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.miter
      ..strokeWidth = width + 2
      ..color = ink;
    canvas.drawPath(path, _paint);
    _paint
      ..strokeWidth = width
      ..color = color;
    canvas.drawPath(path, _paint);
  }

  void rune(Offset at, Color c) {
    if (charge <= .1) return;
    final radius = 2 + charge * 3;
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(time * 1.4);
    _paint
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset.zero,
        width: radius * 2,
        height: radius * 2,
      ),
      _paint,
    );
    canvas.restore();
    r(at.dx - 1, at.dy - 1, 2, 2, ivory);
  }

  void _goblin() {
    const skin = Color(0xFF87A64A), shade = Color(0xFF536B38);
    final step = striding ? sway * 2 : 0.0;
    limb(
      const Offset(13, 30),
      Offset(10, 34 - step),
      Offset(8, 38 - step),
      shade,
      3,
    );
    limb(
      const Offset(20, 30),
      Offset(22, 34 + step),
      Offset(25, 38 + step),
      skin,
      3,
    );
    box(5, 37 - step, 7, 3, const Color(0xFF60462E));
    box(21, 37 + step, 7, 3, const Color(0xFF60462E));
    shape(const [
      Offset(10, 24),
      Offset(22, 23),
      Offset(25, 31),
      Offset(12, 33),
      Offset(8, 29),
    ], const Color(0xFF93462F));
    r(12, 28, 10, 2, gold);
    // Oversized pointed ears, sloping brow and protruding tusks.
    shape(const [
      Offset(10, 15),
      Offset(2, 13),
      Offset(6, 21),
      Offset(12, 23),
    ], shade);
    shape(const [
      Offset(23, 15),
      Offset(31, 12),
      Offset(28, 20),
      Offset(22, 22),
    ], skin);
    shape(const [
      Offset(10, 13),
      Offset(21, 12),
      Offset(26, 17),
      Offset(26, 23),
      Offset(20, 26),
      Offset(10, 23),
      Offset(8, 18),
    ], skin);
    r(10, 14, 10, 2, const Color(0xFFAAC66A));
    r(13, 18, 4, 2, ink);
    r(21, 17, 4, 2, ink);
    r(15, 19, 2, 1, gold);
    r(23, 18, 2, 1, gold);
    r(17, 23, 7, 1, ink);
    r(17, 22, 1, 3, ivory);
    r(23, 21, 1, 3, ivory);
    final hand = Offset(27 + strike * 2, 28 - charge * 12 + sway);
    limb(
      const Offset(10, 26),
      const Offset(6, 29),
      Offset(8, 32 - charge * 12),
      shade,
      3,
    );
    limb(const Offset(22, 26), const Offset(25, 28), hand, skin, 3);
    // A short chipped knife, not the player's full-sized sword.
    canvas.save();
    canvas.translate(hand.dx, hand.dy);
    canvas.rotate(strike * 1.7);
    box(-1, -3, 3, 7, const Color(0xFF754632));
    shape(const [
      Offset(-2, -4),
      Offset(-1, -13),
      Offset(3, -8),
      Offset(2, -3),
    ], element == null ? const Color(0xFFB8BFB0) : magic);
    canvas.restore();
    rune(Offset(15, 17 - charge * 6), const Color(0xFFE99643));
  }

  void _elf(bool frost) {
    final cloak = frost ? const Color(0xFF365776) : const Color(0xFF59416C);
    final trim = frost ? const Color(0xFF8ED5DC) : const Color(0xFFBB799D);
    const skin = Color(0xFF9587AE);
    final hem = sway * 1.3;
    // Tall asymmetric cloak and white hair define the elven silhouette.
    shape([
      const Offset(12, 14),
      const Offset(21, 15),
      Offset(25 + hem, 36),
      const Offset(17, 34),
      const Offset(8, 38),
      Offset(5 + hem, 34),
    ], cloak);
    shape(const [
      Offset(13, 17),
      Offset(19, 17),
      Offset(21, 32),
      Offset(15, 34),
      Offset(11, 29),
    ], const Color(0xFF262C43));
    r(15, 19, 1, 11, trim);
    box(11, 35, 5, 4, cloak);
    box(19, 34, 5, 5, cloak);
    shape(const [
      Offset(11, 6),
      Offset(20, 5),
      Offset(23, 9),
      Offset(22, 16),
      Offset(14, 17),
      Offset(11, 13),
    ], skin);
    shape(const [
      Offset(13, 9),
      Offset(5, 5),
      Offset(9, 13),
      Offset(14, 13),
    ], skin);
    shape(const [
      Offset(22, 9),
      Offset(29, 5),
      Offset(26, 12),
      Offset(21, 13),
    ], skin);
    shape(const [
      Offset(10, 7),
      Offset(12, 3),
      Offset(21, 3),
      Offset(24, 7),
      Offset(19, 6),
      Offset(16, 12),
      Offset(14, 8),
      Offset(11, 22),
      Offset(8, 19),
    ], const Color(0xFFD8D5DC));
    r(18, 10, 4, 1, ink);
    r(20, 11, 2, 1, trim);
    r(20, 14, 2, 1, ink);
    box(15, 16, 6, 3, trim);
    final hand = Offset(25 + strike * 2, 24 - charge * 13);
    limb(const Offset(20, 18), const Offset(23, 21), hand, cloak, 3);
    box(hand.dx - 1, hand.dy - 1, 3, 3, skin);
    if (frost) {
      // Ice spear: fine shaft, forked crystalline head.
      canvas.save();
      canvas.translate(hand.dx, hand.dy);
      canvas.rotate(strike * 1.3);
      box(-1, -13, 3, 27, const Color(0xFF638496));
      shape(const [
        Offset(0, -20),
        Offset(4, -14),
        Offset(1, -10),
        Offset(-3, -14),
      ], element == null ? trim : magic);
      r(0, -17, 1, 6, ivory);
      canvas.restore();
    } else {
      box(hand.dx, hand.dy - 14, 2, 28, const Color(0xFF7B5D62));
      shape([
        Offset(hand.dx - 3, hand.dy - 13),
        Offset(hand.dx - 4, hand.dy - 18),
        Offset(hand.dx, hand.dy - 16),
        Offset(hand.dx + 4, hand.dy - 19),
        Offset(hand.dx + 3, hand.dy - 13),
      ], trim);
      r(
        hand.dx,
        hand.dy - 16,
        2,
        3,
        element == null ? const Color(0xFFB3C966) : magic,
      );
    }
    rune(Offset(10, 21 - charge * 8), trim);
  }

  void _golem() {
    const stone = Color(0xFF6F8270),
        moss = Color(0xFF7EAA58),
        dark = Color(0xFF405954);
    box(7, 30, 8, 9, dark);
    box(19, 30, 9, 9, stone);
    final fist = Offset(28 + strike * 2, 25 - charge * 8 - strike * 3);
    limb(
      const Offset(9, 18),
      Offset(4, 23 + sway),
      Offset(4, 31 + sway),
      dark,
      7,
    );
    limb(const Offset(25, 17), const Offset(29, 22), fist, stone, 7);
    shape(const [
      Offset(7, 13),
      Offset(22, 11),
      Offset(28, 17),
      Offset(25, 31),
      Offset(13, 34),
      Offset(6, 26),
    ], stone);
    shape(const [
      Offset(12, 5),
      Offset(22, 6),
      Offset(25, 13),
      Offset(20, 19),
      Offset(11, 17),
      Offset(8, 11),
    ], dark);
    r(11, 7, 9, 3, moss);
    r(14, 12, 3, 2, gold);
    r(21, 11, 3, 2, gold);
    r(9, 20, 5, 3, moss);
    r(19, 27, 6, 2, dark);
    r(15, 23, 2, 6, dark);
    r(11, 23, 6, 1, const Color(0xFFA5B8A0));
    box(fist.dx - 3, fist.dy - 3, 7, 8, stone);
    rune(const Offset(18, 22), element == null ? moss : magic);
  }

  void _scarab() {
    const shell = Color(0xFFB88035),
        bright = Color(0xFFF1CC69),
        teal = Color(0xFF39877E);
    for (var i = 0; i < 3; i++) {
      final y = 24.0 + i * 4;
      final walk = math.sin(time * (striding ? 24 : 4) + i) * 2;
      limb(Offset(13, y), Offset(5, y - 2 + walk), Offset(3, y + 4), shell, 2);
      limb(
        Offset(21, y),
        Offset(29, y - 2 - walk),
        Offset(30, y + 4),
        bright,
        2,
      );
    }
    shape(const [
      Offset(9, 19),
      Offset(20, 17),
      Offset(26, 23),
      Offset(25, 32),
      Offset(18, 36),
      Offset(9, 32),
      Offset(6, 25),
    ], shell);
    shape(const [
      Offset(11, 20),
      Offset(17, 19),
      Offset(17, 33),
      Offset(10, 30),
      Offset(8, 25),
    ], bright);
    r(18, 21, 1, 12, ink);
    r(11, 23, 4, 2, teal);
    r(21, 25, 3, 4, teal);
    box(13, 14, 12, 8, teal);
    r(17, 16, 2, 2, ivory);
    r(23, 16, 2, 2, ivory);
    final lift = charge * 3 + strike * 4;
    shape([
      const Offset(15, 16),
      Offset(10, 10 - lift),
      Offset(12, 5 - lift),
      Offset(15, 11 - lift),
      const Offset(18, 15),
    ], bright);
    shape([
      const Offset(23, 15),
      Offset(29, 10 - lift),
      Offset(27, 5 - lift),
      Offset(24, 11 - lift),
      const Offset(21, 14),
    ], bright);
    rune(Offset(20, 8 - charge * 3), element == null ? bright : magic);
  }

  void _harpy() {
    const plumage = Color(0xFF5A819C),
        pale = Color(0xFFC4D7D8),
        skin = Color(0xFFAF9AA2);
    final flap = math.sin(time * 6) * 2 - charge * 5;
    shape([
      const Offset(13, 17),
      Offset(4, 11 + flap),
      Offset(1, 10 + flap),
      Offset(2, 25 + flap),
      Offset(5, 21 + flap),
      Offset(7, 27 + flap),
      const Offset(15, 23),
    ], plumage);
    shape([
      const Offset(20, 17),
      Offset(28, 10 + flap),
      Offset(31, 9 + flap),
      Offset(30, 23 + flap),
      Offset(27, 20 + flap),
      Offset(25, 26 + flap),
      const Offset(18, 23),
    ], pale);
    shape(const [
      Offset(13, 15),
      Offset(21, 15),
      Offset(23, 25),
      Offset(18, 31),
      Offset(12, 27),
    ], plumage);
    r(15, 18, 5, 8, pale);
    shape(const [
      Offset(14, 7),
      Offset(20, 6),
      Offset(23, 11),
      Offset(20, 16),
      Offset(13, 14),
    ], skin);
    shape(const [
      Offset(12, 8),
      Offset(13, 3),
      Offset(17, 5),
      Offset(22, 2),
      Offset(22, 8),
      Offset(18, 7),
      Offset(13, 11),
    ], pale);
    r(19, 10, 3, 1, ink);
    r(21, 12, 4, 2, gold);
    for (var i = 0; i < 2; i++) {
      final x = 14.0 + i * 7;
      final kick = i == 1 ? strike * 5 : sway;
      limb(
        Offset(x, 28),
        Offset(x - 1, 33 - kick),
        Offset(x + 2, 37 - kick),
        gold,
        2,
      );
      r(x, 37 - kick, 5, 1, ivory);
    }
    rune(const Offset(25, 15), element == null ? pale : magic);
  }

  void _ent() {
    const bark = Color(0xFF806348),
        dark = Color(0xFF4E4937),
        leaf = Color(0xFF608659);
    // Roots, branch fingers and a crown of leaves, not humanoid clothing.
    shape(const [
      Offset(11, 27),
      Offset(23, 27),
      Offset(24, 34),
      Offset(30, 38),
      Offset(21, 38),
      Offset(17, 34),
      Offset(13, 39),
      Offset(4, 39),
      Offset(9, 34),
    ], bark);
    limb(
      const Offset(10, 18),
      Offset(5, 22 - charge * 7),
      Offset(2, 29 - charge * 12),
      dark,
      3,
    );
    limb(
      const Offset(23, 18),
      Offset(28, 20 - charge * 7),
      Offset(29 + strike * 2, 28 - charge * 12),
      bark,
      4,
    );
    shape(const [
      Offset(12, 8),
      Offset(21, 8),
      Offset(24, 30),
      Offset(18, 33),
      Offset(10, 29),
    ], bark);
    limb(const Offset(14, 12), const Offset(9, 6), const Offset(5, 2), dark, 2);
    limb(
      const Offset(20, 11),
      const Offset(25, 6),
      const Offset(29, 3),
      bark,
      2,
    );
    shape([
      const Offset(5, 6),
      Offset(8 + sway, 1),
      const Offset(14, 2),
      const Offset(18, 0),
      const Offset(25, 4),
      const Offset(29, 9),
      const Offset(22, 12),
      const Offset(10, 11),
    ], leaf);
    r(8, 5, 5, 2, const Color(0xFF91AC65));
    r(19, 7, 5, 2, const Color(0xFF395F48));
    r(13, 16, 3, 2, gold);
    r(20, 15, 3, 2, gold);
    r(16, 21, 5, 2, dark);
    r(13, 25, 1, 6, dark);
    r(21, 24, 1, 6, dark);
    r(1, 26 - charge * 12, 2, 6, leaf);
    r(29, 25 - charge * 12, 2, 7, leaf);
    rune(
      const Offset(18, 25),
      element == null ? const Color(0xFFCADF8A) : magic,
    );
  }

  void _troll() {
    const skin = Color(0xFF718D9D), shadow = Color(0xFF45596F);
    final walk = striding ? sway * 2 : 0.0;
    box(7, 29 - walk, 9, 10, shadow);
    box(20, 30 + walk, 10, 9, skin);
    limb(
      const Offset(8, 17),
      const Offset(4, 22),
      Offset(3, 31 - charge * 10),
      shadow,
      6,
    );
    shape(const [
      Offset(8, 11),
      Offset(22, 12),
      Offset(28, 21),
      Offset(26, 30),
      Offset(11, 32),
      Offset(5, 25),
    ], skin);
    shape(const [
      Offset(12, 5),
      Offset(23, 5),
      Offset(27, 13),
      Offset(24, 19),
      Offset(14, 18),
      Offset(10, 12),
    ], skin);
    r(12, 5, 8, 2, shadow);
    r(16, 11, 3, 1, ink);
    r(23, 10, 3, 1, ink);
    r(17, 15, 8, 2, ink);
    r(17, 13, 2, 5, ivory);
    r(24, 12, 2, 5, ivory);
    r(14, 24, 10, 5, const Color(0xFF806047));
    r(18, 25, 3, 3, gold);
    shape(const [
      Offset(10, 14),
      Offset(11, 19),
      Offset(14, 17),
      Offset(13, 23),
      Offset(16, 20),
    ], gold);
    final hand = Offset(28, 24 - charge * 9);
    limb(const Offset(24, 18), const Offset(28, 21), hand, skin, 5);
    canvas.save();
    canvas.translate(hand.dx, hand.dy);
    canvas.rotate(strike * 1.8);
    box(-2, -12, 4, 20, const Color(0xFF806047));
    box(-5, -16, 10, 8, shadow);
    r(-3, -14, 6, 2, element == null ? gold : magic);
    canvas.restore();
    rune(const Offset(17, 22), gold);
  }

  void _spider() {
    const chitin = Color(0xFF654F70),
        shadow = Color(0xFF40364E),
        venom = Color(0xFFB1C95D);
    for (var i = 0; i < 4; i++) {
      final root = Offset(13 + i * 3.0, 26);
      final twitch = math.sin(time * (striding ? 26 : 5) + i) * 2;
      limb(
        root,
        Offset(4 + i * 3.0, 20 - i + twitch - charge * 3),
        Offset(1 + i * 3.0, 37),
        shadow,
        1,
      );
      limb(
        root,
        Offset(22 + i * 3.0, 21 + i - twitch - charge * 3),
        Offset(21 + i * 3.0, 38 - strike * 4),
        chitin,
        1,
      );
    }
    shape(const [
      Offset(5, 19),
      Offset(8, 14),
      Offset(16, 13),
      Offset(22, 18),
      Offset(22, 28),
      Offset(16, 32),
      Offset(7, 29),
      Offset(3, 24),
    ], chitin);
    r(8, 17, 6, 2, const Color(0xFF94778E));
    r(10, 20, 3, 7, venom);
    r(7, 22, 9, 2, venom);
    shape(const [
      Offset(20, 21),
      Offset(28, 20),
      Offset(31, 24),
      Offset(29, 30),
      Offset(22, 31),
      Offset(19, 27),
    ], shadow);
    for (final eye in const [
      Offset(22, 23),
      Offset(26, 22),
      Offset(28, 25),
      Offset(24, 26),
    ]) {
      r(eye.dx, eye.dy, 2, 2, venom);
    }
    r(27 + strike * 2, 30, 2, 5, ivory);
    r(23 + strike * 2, 31, 2, 4, ivory);
    rune(const Offset(25, 17), element == null ? venom : magic);
  }

  void _drake() {
    const scales = Color(0xFF955040),
        shadow = Color(0xFF543D40),
        lava = Color(0xFFEEA052);
    // Long tail and triangular wing keep the final boss unmistakably draconic.
    final flap = sway * 2 - charge * 3;
    shape([
      const Offset(16, 29),
      const Offset(7, 33),
      Offset(1, 25 + sway),
      const Offset(2, 36),
      const Offset(13, 37),
      const Offset(21, 32),
    ], shadow);
    shape([
      const Offset(15, 24),
      Offset(5, 8 + flap),
      Offset(7, 1 + flap),
      Offset(15, 9 + flap),
      Offset(22, 5 + flap),
      const Offset(24, 24),
    ], shadow);
    shape([
      const Offset(15, 23),
      Offset(8, 7 + flap),
      Offset(14, 12 + flap),
      Offset(20, 9 + flap),
      const Offset(21, 24),
    ], scales);
    shape(const [
      Offset(13, 18),
      Offset(23, 17),
      Offset(28, 27),
      Offset(23, 34),
      Offset(12, 32),
      Offset(9, 26),
    ], scales);
    box(12, 31, 7, 8, shadow);
    box(24, 30, 7, 9, scales);
    r(14, 37, 5, 2, ivory);
    r(26, 37, 5, 2, ivory);
    shape(const [
      Offset(20, 20),
      Offset(20, 10),
      Offset(26, 7),
      Offset(29, 12),
      Offset(32, 15),
      Offset(31, 20),
      Offset(26, 20),
      Offset(25, 27),
    ], scales);
    shape(const [Offset(21, 11), Offset(19, 3), Offset(24, 8)], ivory);
    shape(const [Offset(26, 9), Offset(27, 2), Offset(30, 11)], ivory);
    r(26, 13, 4, 2, ink);
    r(28, 13, 2, 1, lava);
    r(27, 18, 5, 1, ink);
    r(28, 19, 1, 2, ivory);
    r(31, 19, 1, 2, ivory);
    r(22, 22, 3, 7, lava);
    r(16, 24, 2, 5, lava);
    r(13, 22, 3, 1, lava);
    limb(
      const Offset(23, 24),
      Offset(28, 27 - charge * 5),
      Offset(30 + strike * 2, 29 - charge * 8),
      shadow,
      3,
    );
    if (element != null || charge > .1) {
      r(29, 20, 3, 3, magic);
      rune(const Offset(29, 24), magic);
    }
  }
}
