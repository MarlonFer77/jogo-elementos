import 'dart:math' as math;
import 'dart:ui';

import '../game_domain/arena_theme.dart';

enum _Landmark {
  woods,
  fortress,
  volcano,
  ice,
  marsh,
  temple,
  cliffs,
  ruins,
  crypt,
}

enum _Weather { leaves, embers, snow, mist, dust, rain, motes }

class _Style {
  const _Style(
    this.sky,
    this.far,
    this.near,
    this.ground,
    this.floor,
    this.accent,
    this.landmark,
    this.weather,
  );
  final int sky, far, near, ground, floor, accent;
  final _Landmark landmark;
  final _Weather weather;
}

const _styles = {
  ArenaTheme.training: _Style(
    0xFFA5CED0,
    0xFF779E94,
    0xFF416C50,
    0xFF608C60,
    0xFFC2B487,
    0xFFB8CD80,
    _Landmark.woods,
    _Weather.leaves,
  ),
  ArenaTheme.multiplayer: _Style(
    0xFFB6CBD1,
    0xFF83959C,
    0xFF556978,
    0xFF737C73,
    0xFFBBB5A0,
    0xFFD5B96C,
    _Landmark.fortress,
    _Weather.dust,
  ),
  ArenaTheme.embers: _Style(
    0xFFD6A278,
    0xFFA46C5A,
    0xFF654E4C,
    0xFF544945,
    0xFFA28770,
    0xFFFFBA69,
    _Landmark.volcano,
    _Weather.embers,
  ),
  ArenaTheme.glacier: _Style(
    0xFF354C69,
    0xFF4A6F8B,
    0xFF5A8DA4,
    0xFF5E8997,
    0xFFBCD5D6,
    0xFFD1F1EB,
    _Landmark.ice,
    _Weather.snow,
  ),
  ArenaTheme.swamp: _Style(
    0xFF9CB3A0,
    0xFF738D78,
    0xFF395E54,
    0xFF4E7264,
    0xFF999D7B,
    0xFFBCD290,
    _Landmark.marsh,
    _Weather.mist,
  ),
  ArenaTheme.sunTemple: _Style(
    0xFFE4C795,
    0xFFC4A371,
    0xFF947650,
    0xFFAD966B,
    0xFFD9C697,
    0xFFFFE5A4,
    _Landmark.temple,
    _Weather.dust,
  ),
  ArenaTheme.stormCliffs: _Style(
    0xFF82949D,
    0xFF657E8C,
    0xFF3F5B70,
    0xFF586D73,
    0xFFADB7B4,
    0xFFCCDFDE,
    _Landmark.cliffs,
    _Weather.rain,
  ),
  ArenaTheme.moonRuins: _Style(
    0xFF333B59,
    0xFF525974,
    0xFF373F55,
    0xFF4C5860,
    0xFF9393A0,
    0xFFD1C9E7,
    _Landmark.ruins,
    _Weather.motes,
  ),
  ArenaTheme.ancientGrove: _Style(
    0xFF89A992,
    0xFF5E8670,
    0xFF2D5948,
    0xFF3D694D,
    0xFFABAA7B,
    0xFFD4DB92,
    _Landmark.woods,
    _Weather.motes,
  ),
  ArenaTheme.thunderPeaks: _Style(
    0xFF545D7D,
    0xFF626F89,
    0xFF3F4F6D,
    0xFF4E5C6D,
    0xFF9CABB2,
    0xFFEADCA0,
    _Landmark.cliffs,
    _Weather.rain,
  ),
  ArenaTheme.plagueCrypt: _Style(
    0xFF3E494A,
    0xFF55645B,
    0xFF334B42,
    0xFF465B4A,
    0xFF909C7A,
    0xFFC1C88A,
    _Landmark.crypt,
    _Weather.mist,
  ),
  ArenaTheme.caldera: _Style(
    0xFF533F4A,
    0xFF775450,
    0xFF493C42,
    0xFF43393C,
    0xFF9B8173,
    0xFFF1A05C,
    _Landmark.volcano,
    _Weather.embers,
  ),
};

/// Small deterministic pixel shapes, no images/shaders/random allocation per tick.
/// Weather stays behind the combatants and never implies a gameplay modifier.
void drawArenaScenery(
  Canvas canvas,
  Size size, {
  ArenaTheme theme = ArenaTheme.training,
  double time = 0,
}) {
  if (size.isEmpty || !size.width.isFinite || !size.height.isFinite) return;
  final s = _styles[theme]!;
  final w = size.width, h = size.height;
  final t = time.isFinite ? time % 3600 : 0.0;
  final paint = Paint()..isAntiAlias = false;
  void block(double x, double y, double width, double height, int color) {
    if (width <= 0 || height <= 0) return;
    paint.color = Color(color);
    canvas.drawRect(
      Rect.fromLTWH(
        x.roundToDouble(),
        y.roundToDouble(),
        width.ceilToDouble(),
        height.ceilToDouble(),
      ),
      paint,
    );
  }

  void crystal(double x, double y, double height) {
    block(x, y - height, 8, height, s.near);
    block(x + 2, y - height + 4, 3, height - 4, s.accent);
    block(x - 3, y - height * .6, 3, height * .6, s.far);
  }

  void tree(double x, double y, double scale) {
    block(x + 9 * scale, y, 6 * scale, 35 * scale, 0xFF665846);
    block(x - 8 * scale, y - 8 * scale, 38 * scale, 27 * scale, s.near);
    block(x - 2 * scale, y - 20 * scale, 26 * scale, 20 * scale, s.far);
    block(x + 4 * scale, y - 27 * scale, 14 * scale, 9 * scale, s.far);
  }

  canvas.save();
  canvas.clipRect(Offset.zero & size);
  block(0, 0, w, h, s.sky);
  // The upper third stays calm for HP/AP overlays.
  if (theme == ArenaTheme.sunTemple || theme == ArenaTheme.moonRuins) {
    final x = w * .5, y = h * .43;
    block(x - 10, y - 14, 20, 28, s.accent);
    block(x - 14, y - 9, 28, 18, s.accent);
    if (theme == ArenaTheme.moonRuins) block(x, y - 15, 15, 22, s.sky);
  }
  for (var i = 0; i < 6; i++) {
    final x = w * (i * .22 - .12), y = h * (.49 + (i % 3) * .035);
    block(x, y, w * .3, h * .27, s.far);
    block(x + w * .045, y - h * .05, w * .21, h * .06, s.far);
    block(x + w * .09, y - h * .09, w * .1, h * .05, s.far);
  }
  block(0, h * .65, w, h * .35, s.ground);
  switch (s.landmark) {
    case _Landmark.woods:
    case _Landmark.marsh:
      for (var i = 0; i < 9; i++) {
        tree(
          w * i / 8 - 12,
          h * .57 + (i % 3) * 5,
          theme == ArenaTheme.ancientGrove ? 1.5 : 1,
        );
      }
      if (s.landmark == _Landmark.marsh) {
        for (var i = 0; i < 8; i++) {
          block(w * i / 7, h * .7 + (i % 2) * 3, w * .12, 3, s.far);
          block(w * i / 7 + 9, h * .69, 3, 9, s.accent);
        }
      }
    case _Landmark.volcano:
      final cx = w * .5;
      for (var i = 0; i < 6; i++) {
        block(
          cx - w * (.055 + i * .025),
          h * (.43 + i * .037),
          w * (.11 + i * .05),
          h * .05,
          s.near,
        );
      }
      block(cx - w * .04, h * .43, w * .08, 4, s.accent);
      for (var i = 0; i < 5; i++) {
        block(
          cx + (i.isEven ? 0 : 5),
          h * (.45 + i * .043),
          5 + i * 2,
          h * .05,
          s.accent,
        );
      }
      block(0, h * .7, w, 4, s.accent);
    case _Landmark.ice:
      for (var i = 0; i < 9; i++) {
        crystal(w * i / 8, h * .7, h * (.12 + (i % 3) * .055));
        block(w * i / 8, 0, 9, h * (.12 + (i % 3) * .04), s.near);
      }
    case _Landmark.cliffs:
      for (var i = 0; i < 5; i++) {
        final x = w * i / 4, y = h * (.59 + (i % 2) * .04);
        block(x - 16, y, 32, h * .15, s.near);
        block(x - 19, y, 38, 4, s.accent);
        block(x - 5, y + 6, 3, 22, s.far);
      }
      // Banners show wind direction, with no flashing lightning.
      for (final x in [w * .1, w * .9]) {
        block(x, h * .44, 3, h * .26, s.near);
        block(x + 3, h * .44, 18, 11, s.accent);
        block(x + 18, h * .44 + math.sin(t * 2) * 2, 8, 7, s.accent);
      }
    case _Landmark.fortress:
    case _Landmark.temple:
    case _Landmark.ruins:
    case _Landmark.crypt:
      for (var i = 0; i < 6; i++) {
        final x = w * (.02 + i * .19);
        final broken = s.landmark == _Landmark.ruins && i.isOdd;
        final top = h * (broken ? .57 : .43);
        block(x, top, 15, h * .71 - top, s.near);
        block(x + 3, top + 4, 3, h * .69 - top, s.far);
        block(x - 3, top, 21, 5, s.accent);
        block(x - 4, h * .7, 23, 5, s.far);
        if (s.landmark == _Landmark.fortress) {
          block(x + 8, top + 8, 13, 20, i.isEven ? 0xFF82585B : 0xFF50788A);
          block(x + 12, top + 13, 5, 5, s.accent);
        }
      }
      if (s.landmark == _Landmark.temple) {
        block(w * .09, h * .4, w * .82, 8, s.near);
        block(w * .13, h * .38, w * .74, 5, s.accent);
      }
      if (s.landmark == _Landmark.crypt) {
        for (var i = 0; i < 5; i++) {
          final x = w * (.09 + i * .2);
          block(x, h * .59, 20, h * .1, s.sky);
          block(x + 4, h * .56, 12, h * .04, s.sky);
          block(x + 8, h * .64, 4, 4, s.accent);
        }
      }
  }
  // Continuous floor leaves room for melee movement and readable silhouettes.
  block(0, h * .71, w, 5, s.near);
  block(w * .025, h * .755, w * .95, h * .18, s.near);
  block(w * .035, h * .765, w * .93, h * .15, s.floor);
  for (var i = 0; i < 16; i++) {
    final x = w * (.055 + ((i * 7) % 16) / 18);
    final y = h * (.785 + (i % 3) * .046);
    block(x, y, 10, 2, s.ground);
    block(x + 10, y - 3, 2, 5, s.ground);
  }
  // Inlaid central seal: understated, not an active hazard.
  for (var i = 0; i < 5; i++) {
    final offset = (i - 2).abs();
    block(
      w * .5 - 18 + offset * 6,
      h * .817 + i * 3,
      36 - offset * 12,
      2,
      s.ground,
    );
  }
  for (var i = 0; i < 12; i++) {
    final x = w * i / 11, y = h * .96 + (i % 2) * 3;
    block(x - 5, y, 14, 4, s.near);
    block(x, y - 4, 7, 5, s.far);
  }
  // Fixed budget: 14 particles, clipped away from HP/AP and action captions.
  for (var i = 0; i < 14; i++) {
    final x = ((i * .137 + t * .018) % 1) * w;
    final rising = s.weather == _Weather.embers || s.weather == _Weather.motes;
    final phase = (i * .231 + t * .065) % 1;
    final y = h * (.39 + (rising ? 1 - phase : phase) * .32);
    switch (s.weather) {
      case _Weather.rain:
        block(x, y, 2, 7, s.accent);
      case _Weather.mist:
        block(x, y, 18, 2, s.far);
      case _Weather.leaves:
        block(x, y, 5, 2, s.accent);
        block(x + 2, y + 2, 3, 2, s.accent);
      case _Weather.snow:
        block(x, y, 3, 3, s.accent);
      case _Weather.embers:
      case _Weather.dust:
      case _Weather.motes:
        block(x, y, 2, 2, s.accent);
    }
  }
  canvas.restore();
}
