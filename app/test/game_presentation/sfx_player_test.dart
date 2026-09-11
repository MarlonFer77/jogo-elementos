import 'package:app/game_presentation/sfx_player.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('resolves each SfxId to its expected asset path', () {
    final playedPaths = <String>[];
    final player = SfxPlayer(play: playedPaths.add);

    const expected = {
      SfxId.tap: 'tap.wav',
      SfxId.cast: 'cast.ogg',
      SfxId.impact: 'impact.ogg',
      SfxId.unlock: 'unlock.ogg',
      SfxId.victory: 'victory.ogg',
      SfxId.defeat: 'defeat.ogg',
    };

    for (final entry in expected.entries) {
      player.play(entry.key);
      expect(playedPaths.last, entry.value);
    }
  });

  test('the default SfxPlayer() never throws, even without a real audio '
      'backend (safe to call from any widget test)', () {
    final player = SfxPlayer();
    expect(() => player.play(SfxId.tap), returnsNormally);
  });
}
