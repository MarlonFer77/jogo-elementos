import 'dart:async';
import 'package:flame_audio/flame_audio.dart';

/// Asset paths are presentation-only. Original names simplify attribution.
enum SfxId {
  tap('tap.wav', .35),
  cast('kenney_maximize_005.ogg', .35),
  impact('impact.ogg', .55),
  unlock('unlock.ogg', .5),
  victory('victory.ogg', .55),
  defeat('defeat.ogg', .45),
  swing('kenney_knifeSlice.ogg', .5),
  wind('kenney_knifeSlice2.ogg', .45),
  wings('kenney_cloth3.ogg', .5),
  stone('kenney_impactMining_000.ogg', .55),
  wood('kenney_impactWood_heavy_000.ogg', .5),
  chitin('kenney_impactTin_medium_000.ogg', .4),
  fire('kenney_impactSoft_heavy_000.ogg', .6),
  ice('kenney_impactGlass_medium_000.ogg', .45),
  defend('kenney_impactMetal_light_000.ogg', .4),
  water('kenney_drop_003.ogg', .45),
  lightning('kenney_glitch_002.ogg', .35),
  shadow('kenney_minimize_005.ogg', .4),
  light('kenney_glass_005.ogg', .4),
  heal('kenney_confirmation_002.ogg', .45),
  purify('kenney_confirmation_004.ogg', .4),
  sealNode('kenney_tick_001.ogg', .22, 180),
  sealFail('kenney_error_006.ogg', .35),
  sealWarning('kenney_question_002.ogg', .3);

  const SfxId(this.path, this.volume, [this.lifetimeMs = 1500]);
  final String path;
  final double volume;
  final int lifetimeMs;
}

/// Four voices maximum, no network/audio failures in gameplay.
class SfxPlayer {
  SfxPlayer({void Function(String path)? play, DateTime Function()? now})
    : _play = play,
      _now = now ?? DateTime.now;

  final void Function(String path)? _play;
  final DateTime Function() _now;
  final _lastPlayed = <SfxId, DateTime>{};
  final _voices = <Object>{};
  final _active = <AudioPlayer, double>{};
  final _releaseVoices = <void Function()>{};
  double _volume = 1;

  double get volume => _volume;
  set volume(double value) {
    if (!value.isFinite) return;
    final next = value.clamp(0.0, 1.0);
    if (next == _volume) return;
    _volume = next;
    if (next == 0) {
      for (final release in _releaseVoices.toList()) {
        release();
      }
    } else {
      for (final entry in _active.entries) {
        unawaited(entry.key.setVolume(entry.value * next).catchError((_) {}));
      }
    }
  }

  void play(SfxId id) {
    if (_volume == 0) return;
    final now = _now();
    final previous = _lastPlayed[id];
    if (previous != null && now.difference(previous).inMilliseconds < 65) {
      return;
    }
    _lastPlayed[id] = now;
    if (_play != null) {
      try {
        _play(id.path);
      } catch (_) {
        /* Audio never blocks an action. */
      }
      return;
    }
    _defaultPlay(id);
  }

  void _defaultPlay(SfxId id) {
    if (_voices.length >= 4) return;
    final token = Object();
    _voices.add(token);
    AudioPlayer? player;
    Timer? timeout;
    StreamSubscription<void>? completion;
    var released = false;
    void release() {
      if (released) return;
      released = true;
      _voices.remove(token);
      _releaseVoices.remove(release);
      _active.remove(player);
      timeout?.cancel();
      unawaited(completion?.cancel().catchError((_) {}));
      unawaited(player?.dispose().catchError((_) {}));
    }

    _releaseVoices.add(release);

    // Also catches plugin stream/setup errors outside the returned Future.
    runZonedGuarded(() async {
      player = AudioPlayer()..audioCache = FlameAudio.audioCache;
      _active[player!] = id.volume;
      completion = player!.onPlayerComplete.listen((_) => release());
      await player!.setAudioContext(
        AudioContextConfig(
          focus: AudioContextConfigFocus.mixWithOthers,
        ).build(),
      );
      if (released) return;
      // Some low-latency backends omit completion, so also bound their lifetime.
      timeout = Timer(Duration(milliseconds: id.lifetimeMs), release);
      await player!.play(
        AssetSource(id.path),
        volume: id.volume * _volume,
        mode: PlayerMode.lowLatency,
      );
    }, (_, _) => release());
  }
}

/// Replaceable only for sound assertions in widget tests.
SfxPlayer sfxPlayer = SfxPlayer();
