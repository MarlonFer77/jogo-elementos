import 'dart:convert';
import 'package:app/game_domain/cosmetics.dart';
import 'package:app/game_domain/cosmetic_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(
    () => SharedPreferences.setMockInitialValues({'training_sentinel': 12}),
  );
  test(
    'buy/equip are separate; insufficient funds and invalid ownership rejected',
    () {
      final initial = CosmeticInventory();
      expect(initial.coins, 100);
      expect(() => initial.buy('missing'), throwsStateError);
      expect(() => initial.buy('moon'), throwsStateError);
      expect(() => initial.equip('ember'), throwsStateError);
      final bought = initial.buy('ember');
      expect(bought.coins, 25);
      expect(bought.equipped, HeroOutfit.traveler);
      expect(bought.buy('ember').coins, 25);
      expect(bought.equip('ember').equipped, HeroOutfit.ember);
      expect(initial.owned, {'traveler'});
    },
  );
  test(
    'milestones credit once, including old progress; resets do not regrant',
    () {
      final earned = CosmeticInventory().claimDungeon(level: 3, clears: 1);
      expect(earned.coins, 250);
      expect(earned.claimDungeon(level: 3, clears: 1).coins, 250);
      expect(
        earned
            .claimDungeon(level: 1, clears: 0)
            .claimDungeon(level: 3, clears: 1)
            .coins,
        250,
      );
      expect(earned.claimDungeon(level: 4, clears: 2).coins, 375);
    },
  );
  test(
    'concurrent duplicate purchases debit once and persist equipped outfit',
    () async {
      await Future.wait([
        CosmeticStore().buy('ember'),
        CosmeticStore().buy('ember'),
      ]);
      await CosmeticStore().equip('ember');
      final loaded = await CosmeticStore().load();
      expect(loaded.coins, 25);
      expect(loaded.owned, {'traveler', 'ember'});
      expect(loaded.equipped, HeroOutfit.ember);
      expect(
        (await SharedPreferences.getInstance()).getInt('training_sentinel'),
        12,
      );
    },
  );
  test(
    'corrupt save recovers backup; no backup and future versions stay untouched',
    () async {
      final backup = jsonEncode(CosmeticInventory().buy('ember').toJson());
      SharedPreferences.setMockInitialValues({
        CosmeticStore.key: 'broken',
        '${CosmeticStore.key}.backup.v1': jsonEncode(backup),
      });
      final store = CosmeticStore();
      expect((await store.load()).coins, 25);
      expect(store.recovered, true);
      SharedPreferences.setMockInitialValues({CosmeticStore.key: 'broken'});
      await expectLater(CosmeticStore().buy('ember'), throwsStateError);
      expect(
        (await SharedPreferences.getInstance()).getString(CosmeticStore.key),
        'broken',
      );
      final newer = jsonEncode({...CosmeticInventory().toJson(), 'version': 2});
      SharedPreferences.setMockInitialValues({CosmeticStore.key: newer});
      await expectLater(CosmeticStore().load(), throwsStateError);
      expect(
        (await SharedPreferences.getInstance()).getString(CosmeticStore.key),
        newer,
      );
    },
  );
  test('invalid balances and unowned equipment are rejected', () {
    for (final field in [
      {'coins': -1},
      {'equipped': 'moon'},
      {
        'owned': ['traveler', 'traveler'],
      },
    ]) {
      expect(
        () => CosmeticInventory.fromJson({
          ...CosmeticInventory().toJson(),
          ...field,
        }),
        throwsFormatException,
      );
    }
  });
}
