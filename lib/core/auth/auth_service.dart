import 'package:flutter/foundation.dart' show debugPrint;

import '../storage/local_database.dart';

class AuthService {
  static const localUserId = 'local_catechist_id';
  static const localUserName = 'Catechista Locale';

  final _box = LocalDatabase.auth();

  bool get isPinConfigured => _box.containsKey('local_pin_hash');

  bool get isUnlocked => _box.get('isLoggedIn', defaultValue: false);

  Future<bool> setupInitialPin(String pin) async {
    if (pin.length < 4) {
      debugPrint('Il PIN deve essere di almeno 4 cifre');
      return false;
    }

    try {
      await _box.put('local_pin_hash', pin);
      await _box.put('local_user_name', localUserName);
      await _box.put('isLoggedIn', true);
      return true;
    } catch (e) {
      debugPrint('Errore durante la configurazione del PIN: $e');
      return false;
    }
  }

  Future<bool> signInWithPin(String inputPin) async {
    try {
      final savedPin = _box.get('local_pin_hash');
      if (savedPin == null) return false;

      if (savedPin == inputPin) {
        await _box.put('isLoggedIn', true);
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Errore durante il controllo del PIN: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    await _box.put('isLoggedIn', false);
  }

  Map<String, dynamic>? get currentUser {
    if (!isUnlocked) return null;
    return {
      'uid': localUserId,
      'name': _box.get('local_user_name', defaultValue: localUserName),
      'email': 'locale@dispositivo',
      'role': 'catechist',
      'canManageCatechists': true,
    };
  }
}
