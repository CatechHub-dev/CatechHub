import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/update_service.dart';
import '../storage/local_database.dart';
import 'screen_security.dart';

/// Preferenze di privacy e sicurezza (archivio Hive cifrato `registroBox`).
class PrivacySettings {
  const PrivacySettings({
    required this.lockOnBackground,
    required this.blockScreenshots,
    required this.checkUpdatesOnStart,
    required this.allowRemoteFeedback,
  });

  final bool lockOnBackground;
  final bool blockScreenshots;
  final bool checkUpdatesOnStart;
  final bool allowRemoteFeedback;

  static const defaults = PrivacySettings(
    lockOnBackground: true,
    blockScreenshots: true,
    checkUpdatesOnStart: true,
    allowRemoteFeedback: true,
  );
}

final privacySettingsProvider =
    StateNotifierProvider<PrivacySettingsNotifier, PrivacySettings>(
      (ref) => PrivacySettingsNotifier(),
    );

class PrivacySettingsNotifier extends StateNotifier<PrivacySettings> {
  PrivacySettingsNotifier() : super(loadFromStorage());

  static PrivacySettings loadFromStorage() {
    final box = LocalDatabase.auth();
    return PrivacySettings(
      lockOnBackground: box.get(
        'privacy_lock_on_background',
        defaultValue: true,
      ),
      blockScreenshots: box.get(
        'privacy_block_screenshots',
        defaultValue: true,
      ),
      checkUpdatesOnStart: box.get('privacy_check_updates', defaultValue: true),
      allowRemoteFeedback: box.get(
        'privacy_allow_feedback',
        defaultValue: true,
      ),
    );
  }

  Future<void> _persist() async {
    final box = LocalDatabase.auth();
    await box.put('privacy_lock_on_background', state.lockOnBackground);
    await box.put('privacy_block_screenshots', state.blockScreenshots);
    await box.put('privacy_check_updates', state.checkUpdatesOnStart);
    await box.put('privacy_allow_feedback', state.allowRemoteFeedback);
  }

  Future<void> setLockOnBackground(bool value) async {
    state = PrivacySettings(
      lockOnBackground: value,
      blockScreenshots: state.blockScreenshots,
      checkUpdatesOnStart: state.checkUpdatesOnStart,
      allowRemoteFeedback: state.allowRemoteFeedback,
    );
    await _persist();
  }

  Future<void> setBlockScreenshots(bool value) async {
    state = PrivacySettings(
      lockOnBackground: state.lockOnBackground,
      blockScreenshots: value,
      checkUpdatesOnStart: state.checkUpdatesOnStart,
      allowRemoteFeedback: state.allowRemoteFeedback,
    );
    await _persist();
    await ScreenSecurity.setEnabled(value);
  }

  Future<void> setCheckUpdatesOnStart(bool value) async {
    state = PrivacySettings(
      lockOnBackground: state.lockOnBackground,
      blockScreenshots: state.blockScreenshots,
      checkUpdatesOnStart: value,
      allowRemoteFeedback: state.allowRemoteFeedback,
    );
    await _persist();
    if (value) {
      UpdateService.checkForUpdates();
    }
  }

  Future<void> setAllowRemoteFeedback(bool value) async {
    state = PrivacySettings(
      lockOnBackground: state.lockOnBackground,
      blockScreenshots: state.blockScreenshots,
      checkUpdatesOnStart: state.checkUpdatesOnStart,
      allowRemoteFeedback: value,
    );
    await _persist();
  }

  /// Applica opzioni native (es. FLAG_SECURE) all'avvio.
  static Future<void> applyNativeOptions(PrivacySettings settings) async {
    await ScreenSecurity.setEnabled(settings.blockScreenshots);
  }
}
