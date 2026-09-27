import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dungeon_progress.dart';

class DungeonProgressStore {
  static const key = 'dungeon_profile_v1';

  Future<DungeonProgress> load() async {
    final raw = (await SharedPreferences.getInstance()).get(key);
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
    final saved = await (await SharedPreferences.getInstance()).setString(
      key,
      jsonEncode(progress.toJson()),
    );
    if (!saved) throw StateError('Não foi possível salvar. Tente novamente.');
  }
}
