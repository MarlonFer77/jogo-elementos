import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Native legacy keys stay readable. Backups hold progress only, never tokens.
/// Progress operations are serialized across instances in this isolate.
class RecoverablePreferences {
  RecoverablePreferences({this.onRecovery});
  final void Function()? onRecovery;
  static Future<void>? _pending;

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = (_pending ?? Future<void>.value()).then((_) => action());
    final settled = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    _pending = settled;
    settled.then((_) {
      if (identical(_pending, settled)) _pending = null;
    });
    return result;
  }

  Object? _valid(Object? value, bool Function(Object) validate) {
    if (value == null) return null;
    try {
      return validate(value) ? value : null;
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  Object? _read(
    SharedPreferences prefs,
    String key,
    bool Function(Object) validate,
  ) {
    final raw = prefs.get(key);
    final current = _valid(raw, validate);
    if (current != null) return current;
    final backup = prefs.get('$key.backup.v1');
    Object? recovered;
    try {
      recovered = _valid(
        backup is String ? jsonDecode(backup) : null,
        validate,
      );
    } on FormatException {
      recovered = null;
    }
    if (recovered != null) {
      onRecovery?.call();
      return recovered;
    }
    if (raw != null || backup != null) {
      throw StateError(
        'Progresso ilegível e sem cópia válida. Os dados foram preservados.',
      );
    }
    return null;
  }

  Future<Object?> read(String key, bool Function(Object) validate) =>
      _serial(() async {
        return _read(await SharedPreferences.getInstance(), key, validate);
      });

  Future<void> write(
    String key,
    Object value,
    bool Function(Object) validate,
  ) => _serial(() async {
    if (_valid(value, validate) == null) {
      throw StateError('Progresso inválido. Nada foi gravado.');
    }
    final prefs = await SharedPreferences.getInstance();
    try {
      final previous = _read(prefs, key, validate);
      final raw = prefs.get(key);
      if (raw != null && _valid(raw, validate) == null) {
        await _check(prefs.setString('$key.corrupt.v1', jsonEncode(raw)));
      }
      // Backup first; failed primary writes leave a valid recovery value.
      await _check(
        prefs.setString('$key.backup.v1', jsonEncode(previous ?? value)),
      );
      if (value is String) {
        await _check(prefs.setString(key, value));
      } else if (value is int) {
        await _check(prefs.setInt(key, value));
      } else {
        await _check(prefs.setStringList(key, (value as List).cast<String>()));
      }
    } catch (_) {
      // SharedPreferences updates its cache before the platform confirms a write.
      // Do not let a failed write become the next supposedly valid backup.
      await prefs.reload();
      rethrow;
    }
  });

  Future<void> _check(Future<bool> write) async {
    if (!await write) {
      throw StateError('Não foi possível salvar o progresso. Tente novamente.');
    }
  }
}
