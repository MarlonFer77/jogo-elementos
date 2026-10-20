import 'dart:convert';
import 'beta_session.dart';
import 'recoverable_preferences.dart';

/// Local checkpoints scoped to a verified Firebase UID, not to an email/name.
class BetaAdventureStore {
  BetaAdventureStore(this.uid, {RecoverablePreferences? preferences}) {
    if (uid.isEmpty || uid.length > 128) throw ArgumentError('ID inválido.');
    _preferences =
        preferences ??
        RecoverablePreferences(onRecovery: () => recovered = true);
  }
  final String uid;
  late final RecoverablePreferences _preferences;
  bool recovered = false;
  String get key => 'beta.adventure.v1.${base64Url.encode(utf8.encode(uid))}';

  bool _valid(Object raw) {
    try {
      if (raw is! String || raw.length > 20000) return false;
      final envelope = jsonDecode(raw) as Map<String, dynamic>;
      if (envelope['version'] is int && (envelope['version'] as int) > 1) {
        throw StateError('Save de versão mais recente. Atualize o aplicativo.');
      }
      if (envelope['version'] != 1 || envelope['uid'] != uid) return false;
      BetaCheckpoint.decode(envelope['checkpoint'] as String);
      return true;
    } on FormatException {
      return false;
    } on TypeError {
      return false;
    }
  }

  Future<BetaCheckpoint?> load() async {
    final raw = await _preferences.read(key, _valid);
    if (raw == null) return null;
    return BetaCheckpoint.decode(
      jsonDecode(raw as String)['checkpoint'] as String,
    );
  }

  Future<void> save(BetaCheckpoint checkpoint) => _preferences.write(
    key,
    jsonEncode({'version': 1, 'uid': uid, 'checkpoint': checkpoint.encoded}),
    _valid,
  );
}
