import 'dart:ui';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import '../game_domain/beta_session.dart';
import 'beta_arena_painter.dart';
import 'sfx_player.dart';

class BetaGame extends FlameGame {
  BetaSession session = BetaSession();
  late BetaArenaPainter _painter = BetaArenaPainter(session);
  final hud = ValueNotifier<int>(0);
  double _hudTime = 0;
  void refresh() => hud.value++;
  void restart() {
    session = BetaSession();
    _painter = BetaArenaPainter(session);
    refresh();
  }

  @override
  void update(double dt) {
    super.update(dt);
    session.update(dt);
    for (final event in session.sounds) {
      sfxPlayer.play(switch (event) {
        BetaSound.sword => SfxId.swing,
        BetaSound.cast => SfxId.cast,
        BetaSound.impact => SfxId.impact,
        BetaSound.hurt => SfxId.stone,
        BetaSound.dodge => SfxId.wind,
        BetaSound.level => SfxId.unlock,
        BetaSound.victory => SfxId.victory,
        BetaSound.defeat => SfxId.defeat,
      });
    }
    session.sounds.clear();
    _hudTime += dt;
    if (_hudTime >= .1) {
      _hudTime = 0;
      refresh();
    }
  }

  @override
  void render(Canvas canvas) {
    _painter.paint(canvas, Size(size.x, size.y));
    super.render(canvas);
  }
}
