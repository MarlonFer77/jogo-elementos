import 'dart:convert';
import 'recoverable_preferences.dart';
import 'dungeon_progress.dart';

class DungeonProgressStore {
  DungeonProgressStore() {
    _storage = RecoverablePreferences(onRecovery: () => recovered = true);
  }
  late final RecoverablePreferences _storage;
  bool recovered = false;
  static const key = 'dungeon_profile_v1';

  bool _validate(Object raw) {
    final data = jsonDecode(raw as String) as Map<String, dynamic>;
    if (data['version'] is int &&
        (data['version'] as int) > DungeonProgress.saveVersion) {
      throw StateError(
        'Save de uma versão mais recente. Atualize o aplicativo.',
      );
    }
    DungeonProgress.fromJson(data);
    return true;
  }

  Future<DungeonProgress> load() async {
    final raw = await _storage.read(key, _validate);
    if (raw == null) return DungeonProgress();
    try {
      return DungeonProgress.fromJson(
        jsonDecode(raw as String) as Map<String, dynamic>,
      );
    } catch (_) {
      // Do not replace an unreadable save with a fresh profile.
      throw StateError(
        'Não foi possível ler a expedição. Seu save foi preservado.',
      );
    }
  }

  Future<void> save(DungeonProgress progress) async {
    await _storage.write(key, jsonEncode(progress.toJson()), _validate);
  }
}
