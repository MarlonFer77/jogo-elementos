import 'package:shared_preferences/shared_preferences.dart';

/// Persiste o progresso do Modo Treino (Skill Tree por slot `'a'`/`'b'`,
/// Livro de Descobertas compartilhado) entre partidas e entre execuções
/// do app — `shared_preferences`, local ao aparelho, sem rede, sem
/// custo (Bloco 10).
class TrainingProgressStore {
  static const _unlockedKeyPrefix = 'training_unlocked_';
  static const _discoveredKey = 'training_discovered';

  Future<List<String>> loadUnlockedNodeIds(String slot) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('$_unlockedKeyPrefix$slot') ?? const [];
  }

  Future<void> saveUnlockedNodeIds(String slot, List<String> unlockedNodeIds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('$_unlockedKeyPrefix$slot', unlockedNodeIds);
  }

  Future<List<String>> loadDiscoveredCombinationIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_discoveredKey) ?? const [];
  }

  Future<void> saveDiscoveredCombinationIds(List<String> discoveredCombinationIds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_discoveredKey, discoveredCombinationIds);
  }
}
