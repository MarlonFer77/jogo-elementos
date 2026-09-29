import 'package:app/game_presentation/sfx_player.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:io';
import 'package:app/game_presentation/battle_audio.dart';
import 'package:app/game_domain/attack_event.dart';
import 'package:app/game_domain/combatant_appearance.dart';

void main() {
  test('resolves each SfxId to its expected asset path', () {
    final playedPaths = <String>[];
    final player = SfxPlayer(play: playedPaths.add);

    const expected = {
      SfxId.tap: 'tap.wav',
      SfxId.cast: 'kenney_maximize_005.ogg',
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

  test(
    'all sounds are bundled and repeated input is throttled, not queued',
    () {
      for (final id in SfxId.values) {
        final asset = File('assets/audio/${id.path}');
        expect(asset.existsSync(), isTrue, reason: id.path);
        expect(asset.lengthSync(), greaterThan(100));
        expect(id.volume, inInclusiveRange(.01, 1));
        if (id.path.endsWith('.ogg')) {
          expect(String.fromCharCodes(asset.readAsBytesSync().take(4)), 'OggS');
        }
      }
      var time = DateTime(2026);
      final heard = <String>[];
      final player = SfxPlayer(play: heard.add, now: () => time);
      player.play(SfxId.sealNode);
      player.play(SfxId.sealNode);
      player.play(SfxId.defend);
      expect(heard.length, 2);
      time = time.add(const Duration(milliseconds: 70));
      player.play(SfxId.sealNode);
      expect(heard.length, 3);
      expect(
        () => SfxPlayer(
          play: (_) => throw StateError('audio unavailable'),
        ).play(SfxId.tap),
        returnsNormally,
      );
    },
  );

  test('support and failed actions never use the generic attack impact', () {
    AttackEvent event({
      bool defend = false,
      bool failed = false,
      bool thaw = false,
      int healing = 0,
      bool purified = false,
      List<String> elements = const ['fire'],
    }) => AttackEvent(
      sequenceId: 1,
      attackerIsLeft: true,
      elementIds: elements,
      damage: 0,
      healing: healing,
      purified: purified,
      appliedStatusNames: const [],
      isDefend: defend,
      isFizzle: failed,
      isFrozenRecovery: thaw,
    );
    expect(BattleAudio.impact(event(defend: true)), SfxId.defend);
    expect(BattleAudio.impact(event(failed: true)), SfxId.sealFail);
    expect(BattleAudio.impact(event(thaw: true)), SfxId.ice);
    expect(BattleAudio.impact(event(healing: 12)), SfxId.heal);
    expect(BattleAudio.impact(event(purified: true)), SfxId.purify);
    expect(
      BattleAudio.preparation(
        event(failed: true),
        CombatantAppearance.adventurer,
      ),
      isNull,
    );
    expect(
      BattleAudio.preparation(event(), CombatantAppearance.emberGoblin),
      SfxId.swing,
    );
    expect(
      BattleAudio.preparation(event(), CombatantAppearance.swampGolem),
      SfxId.stone,
    );
    expect(
      BattleAudio.preparation(event(), CombatantAppearance.plagueSpider),
      SfxId.chitin,
    );
    expect(
      BattleAudio.impact(event(elements: ['water', 'ice'])),
      BattleAudio.impact(event(elements: ['ice', 'water'])),
    );
  });

  test('the default SfxPlayer() never throws, even without a real audio '
      'backend (safe to call from any widget test)', () {
    final player = SfxPlayer();
    expect(() => player.play(SfxId.tap), returnsNormally);
  });
}
