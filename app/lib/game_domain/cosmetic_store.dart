import 'dart:convert';
import 'cosmetics.dart';
import 'recoverable_preferences.dart';

/// Offline wallet, not purchasable currency or a trusted multiplayer inventory.
/// Serialize read-modify-write across store instances, including double taps.
class CosmeticStore {
  CosmeticStore() {
    _storage = RecoverablePreferences(onRecovery: () => recovered = true);
  }
  static const key = 'cosmetics_local_v1';
  static Future<void>? _pending;
  late final RecoverablePreferences _storage;
  bool recovered = false;

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = (_pending ?? Future<void>.value()).then((_) => action());
    final settled = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _pending = settled;
    settled.then((_) {
      if (identical(_pending, settled)) _pending = null;
    });
    return result;
  }

  bool _valid(Object value) {
    CosmeticInventory.fromJson(
      jsonDecode(value as String) as Map<String, dynamic>,
    );
    return true;
  }

  Future<CosmeticInventory> _read() async {
    final raw = await _storage.read(key, _valid);
    return raw == null
        ? CosmeticInventory()
        : CosmeticInventory.fromJson(
            jsonDecode(raw as String) as Map<String, dynamic>,
          );
  }

  Future<CosmeticInventory> load() => _serial(_read);
  Future<CosmeticInventory> _update(
    CosmeticInventory Function(CosmeticInventory) change,
  ) => _serial(() async {
    final before = await _read();
    final after = change(before);
    if (!identical(before, after)) {
      await _storage.write(key, jsonEncode(after.toJson()), _valid);
    }
    return after;
  });
  Future<CosmeticInventory> claimDungeon(int level, int clears) =>
      _update((state) => state.claimDungeon(level: level, clears: clears));
  Future<CosmeticInventory> buy(String id) => _update((state) => state.buy(id));
  Future<CosmeticInventory> equip(String id) =>
      _update((state) => state.equip(id));
}
