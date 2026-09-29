import 'dart:convert';

import 'package:app/game_presentation/sfx_player.dart';
import 'package:app/settings/game_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('preferences persist in order without changing progression', () async {
    SharedPreferences.setMockInitialValues({'campaign': 'untouched'});
    final settings = GameSettings();
    final writes = [
      settings.setVolume(.2),
      settings.setVolume(.7),
      settings.setMuted(true),
      settings.markTutorialSeen(),
    ];
    await Future.wait(writes);
    final restored = GameSettings();
    await restored.load();
    expect(restored.volume, .7);
    expect(restored.muted, isTrue);
    expect(restored.effectiveVolume, 0);
    expect(restored.tutorialSeen, isTrue);
    await restored.setMuted(false);
    expect(restored.effectiveVolume, .7);
    expect(
      (await SharedPreferences.getInstance()).getString('campaign'),
      'untouched',
    );
  });

  test('invalid storage is safe and volume is bounded', () async {
    for (final raw in ['broken', '[]', '{"volume":"bad","muted":123}']) {
      SharedPreferences.setMockInitialValues({GameSettings.storageKey: raw});
      final settings = GameSettings();
      await settings.load();
      expect(settings.volume, 1);
      expect(settings.muted, isFalse);
      expect(settings.tutorialSeen, isFalse);
    }
    SharedPreferences.setMockInitialValues({
      GameSettings.storageKey: jsonEncode({'volume': 50}),
    });
    final settings = GameSettings();
    await settings.load();
    expect(settings.volume, 1);
    await settings.setVolume(-1);
    await settings.setVolume(double.nan);
    expect(settings.volume, 0);
  });

  test(
    'mute and zero volume suppress every cue; unmute has no queued sounds',
    () {
      final heard = <String>[];
      final audio = SfxPlayer(play: heard.add);
      audio.volume = 0;
      for (final cue in SfxId.values) {
        audio.play(cue);
      }
      expect(heard, isEmpty);
      audio.volume = .4;
      expect(heard, isEmpty);
      audio.play(SfxId.tap);
      expect(heard, ['tap.wav']);
      audio.volume = double.nan;
      expect(audio.volume, .4);
    },
  );
}
