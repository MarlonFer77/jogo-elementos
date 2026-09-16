import 'package:shared_preferences/shared_preferences.dart';

/// Persiste o progresso do Modo Treino (Skill Tree por slot `'a'`/`'b'`,
/// Livro de Descobertas compartilhado, turnos jogados cumulativos por
/// slot — Bloco 2b) entre partidas e entre execuções do app —
/// `shared_preferences`, local ao aparelho, sem rede, sem custo.
class TrainingProgressStore {
  Future<List<String>?> loadEquippedElementIds(String slot) async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.get('training_elements_equipped_$slot');
    return value is List ? value.whereType<String>().toList() : null;
  }

  Future<void> saveEquippedElementIds(String slot, List<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('training_elements_equipped_$slot', ids);
  }

  static const _unlockedKeyPrefix = 'training_unlocked_';
  static const _discoveredKey = 'training_discovered';
  static const _turnsPlayedKeyPrefix = 'training_turns_played_';
  static const _attacksUnlockedKeyPrefix = 'training_attacks_unlocked_';
  static const _attacksEquippedKeyPrefix = 'training_attacks_equipped_';

  Future<List<String>> loadUnlockedNodeIds(String slot) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('$_unlockedKeyPrefix$slot') ?? const [];
  }

  Future<void> saveUnlockedNodeIds(
    String slot,
    List<String> unlockedNodeIds,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('$_unlockedKeyPrefix$slot', unlockedNodeIds);
  }

  Future<List<String>> loadDiscoveredCombinationIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_discoveredKey) ?? const [];
  }

  Future<void> saveDiscoveredCombinationIds(
    List<String> discoveredCombinationIds,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_discoveredKey, discoveredCombinationIds);
  }

  /// Turnos cumulativos jogados por [slot] (`'a'`/`'b'`), desde sempre —
  /// não reseta em "Nova partida" (Bloco 2b: gate de desbloqueio de
  /// elementos). `0` se nunca salvo.
  Future<int> loadTurnsPlayed(String slot) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_turnsPlayedKeyPrefix$slot') ?? 0;
  }

  Future<void> saveTurnsPlayed(String slot, int turnsPlayed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_turnsPlayedKeyPrefix$slot', turnsPlayed);
  }

  /// Ids das combinações que [slot] já desbloqueou como ataque pessoal
  /// (Bloco 2c) — lista vazia se nunca salvo.
  Future<List<String>> loadUnlockedAttackIds(String slot) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('$_attacksUnlockedKeyPrefix$slot') ?? const [];
  }

  Future<void> saveUnlockedAttackIds(String slot, List<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('$_attacksUnlockedKeyPrefix$slot', ids);
  }

  /// Ids das combinações que [slot] tem equipadas agora (até 3) — lista
  /// vazia se nunca salvo.
  Future<List<String>> loadEquippedAttackIds(String slot) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('$_attacksEquippedKeyPrefix$slot') ?? const [];
  }

  Future<void> saveEquippedAttackIds(String slot, List<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('$_attacksEquippedKeyPrefix$slot', ids);
  }
}
