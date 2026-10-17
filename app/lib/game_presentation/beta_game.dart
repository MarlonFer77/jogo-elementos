import 'dart:ui';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import '../game_domain/beta_session.dart';
import '../game_domain/cosmetics.dart';
import 'beta_arena_painter.dart';
import 'beta_performance.dart';
import 'sfx_player.dart';

class BetaGame extends FlameGame {
  BetaGame({
    this.outfit = HeroOutfit.traveler,
    this.loadout = const BetaLoadout(),
  });
  final HeroOutfit outfit;
  final BetaLoadout loadout;
  late BetaSession session = BetaSession(loadout: loadout);
  late BetaArenaPainter _painter = BetaArenaPainter(session, outfit: outfit);
  final hud = ValueNotifier<int>(0);
  final performance = BetaPerformance();
  bool _reduceMotion = false;
  bool get reduceMotion => _reduceMotion;
  set reduceMotion(bool value) {
    _reduceMotion = value;
    _painter.reduceMotion = value;
  }

  bool _closed = false;
  double _hudTime = 0;
  double get healthTrail => _painter.heroHealthTrail;
  void refresh() {
    if (!_closed) hud.value++;
  }

  void restart() {
    _painter.dispose();
    performance.reset();
    session = BetaSession(loadout: loadout);
    _painter = BetaArenaPainter(
      session,
      reduceMotion: _reduceMotion,
      outfit: outfit,
    );
    refresh();
  }

  @override
  void update(double dt) {
    if (_closed) return;
    super.update(dt);
    if (session.playing) performance.recordLoop(dt);
    final previousHp = session.hp;
    final previousRegion = session.region;
    session.update(dt);
    _painter.advance(dt);
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
        BetaSound.enemySwing => SfxId.swing,
        BetaSound.heavyImpact => SfxId.stone,
        BetaSound.fireImpact => SfxId.fire,
        BetaSound.waterImpact => SfxId.water,
        BetaSound.windImpact => SfxId.wind,
        BetaSound.earthImpact => SfxId.stone,
        BetaSound.passage => SfxId.purify,
        BetaSound.discovery => SfxId.unlock,
        BetaSound.ward => SfxId.purify,
      });
    }
    session.sounds.clear();
    if (!session.playing && !session.settling) {
      // Draw the final frame once; don't keep rebuilding a hidden arena.
      pauseEngine();
      refresh();
      return;
    }
    _hudTime += dt;
    if (_hudTime >= .1 ||
        session.hp != previousHp ||
        session.region != previousRegion) {
      _hudTime = 0;
      refresh();
    }
  }

  @override
  void render(Canvas canvas) {
    if (_closed) return;
    _painter.paint(canvas, Size(size.x, size.y));
    super.render(canvas);
  }

  void close() {
    if (_closed) return;
    _closed = true;
    session.pause();
    pauseEngine();
    _painter.dispose();
    performance.reset();
    hud.dispose();
  }

  @override
  void onDispose() {
    close();
    super.onDispose();
  }
}
