import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device preferences, deliberately separate from player/campaign saves.
class GameSettings extends ChangeNotifier {
  static const storageKey = 'elementos.preferences.v1';
  double _volume = 1;
  bool _muted = false;
  bool _tutorialSeen = false;
  Future<void> _writes = Future.value();
  bool saveFailed = false;

  double get volume => _volume;
  bool get muted => _muted;
  bool get tutorialSeen => _tutorialSeen;
  double get effectiveVolume => _muted ? 0 : _volume;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = jsonDecode(prefs.getString(storageKey) ?? '{}');
      if (data is! Map) return;
      final volume = data['volume'];
      if (volume is num && volume.isFinite) {
        _volume = volume.toDouble().clamp(0, 1);
      }
      _muted = data['muted'] == true;
      _tutorialSeen = data['tutorialSeen'] == true;
    } catch (_) {
      // Unavailable or corrupt preferences must never block startup.
    }
    notifyListeners();
  }

  Future<void> setVolume(double value) {
    if (!value.isFinite) return Future.value();
    _volume = value.clamp(0, 1);
    return _save();
  }

  Future<void> setMuted(bool value) {
    _muted = value;
    return _save();
  }

  Future<void> markTutorialSeen() {
    _tutorialSeen = true;
    return _save();
  }

  Future<void> _save() {
    final snapshot = jsonEncode({
      'volume': _volume,
      'muted': _muted,
      'tutorialSeen': _tutorialSeen,
    });
    notifyListeners();
    // Serialize snapshots so rapid changes cannot persist an older value last.
    return _writes = _writes.then((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        saveFailed = !await prefs.setString(storageKey, snapshot);
      } catch (_) {
        saveFailed = true;
      }
      notifyListeners();
    });
  }
}

final gameSettings = GameSettings();
