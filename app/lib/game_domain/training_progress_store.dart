import 'recoverable_preferences.dart';

/// Local progress only. Legacy keys and independent player slots are preserved.
class TrainingProgressStore {
  TrainingProgressStore() {
    _storage = RecoverablePreferences(onRecovery: () => recovered = true);
  }
  late final RecoverablePreferences _storage;
  bool recovered = false;

  static bool _ids(Object value) =>
      value is List && value.every((id) => id is String);
  static bool _turns(Object value) => value is int && value >= 0;
  Future<List<String>?> _load(String key) async =>
      (await _storage.read(key, _ids) as List?)?.cast<String>().toList();
  Future<void> _save(String key, List<String> ids) =>
      _storage.write(key, List<String>.of(ids), _ids);

  Future<List<String>?> loadEquippedElementIds(String slot) =>
      _load('training_elements_equipped_$slot');
  Future<void> saveEquippedElementIds(String slot, List<String> ids) =>
      _save('training_elements_equipped_$slot', ids);
  Future<List<String>> loadUnlockedNodeIds(String slot) async =>
      await _load('training_unlocked_$slot') ?? [];
  Future<void> saveUnlockedNodeIds(String slot, List<String> ids) =>
      _save('training_unlocked_$slot', ids);
  Future<List<String>> loadDiscoveredCombinationIds() async =>
      await _load('training_discovered') ?? [];
  Future<void> saveDiscoveredCombinationIds(List<String> ids) =>
      _save('training_discovered', ids);
  Future<int> loadTurnsPlayed(String slot) async =>
      await _storage.read('training_turns_played_$slot', _turns) as int? ?? 0;
  Future<void> saveTurnsPlayed(String slot, int turns) =>
      _storage.write('training_turns_played_$slot', turns, _turns);
  Future<List<String>> loadUnlockedAttackIds(String slot) async =>
      await _load('training_attacks_unlocked_$slot') ?? [];
  Future<void> saveUnlockedAttackIds(String slot, List<String> ids) =>
      _save('training_attacks_unlocked_$slot', ids);
  Future<List<String>> loadEquippedAttackIds(String slot) async =>
      await _load('training_attacks_equipped_$slot') ?? [];
  Future<void> saveEquippedAttackIds(String slot, List<String> ids) =>
      _save('training_attacks_equipped_$slot', ids);
}
