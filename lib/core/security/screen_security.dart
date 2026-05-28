import 'dart:io';

import 'package:flutter/services.dart';

/// Blocca screenshot e registrazione schermo su Android (FLAG_SECURE).
class ScreenSecurity {
  static const _channel =
      MethodChannel('com.delelimed.registro_catechismo/security');

  static Future<void> setEnabled(bool enabled) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('setSecureFlag', {'enabled': enabled});
    } catch (_) {
      // Ignora su emulatori o build senza canale nativo.
    }
  }
}
