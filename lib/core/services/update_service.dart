import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

/// Controllo opzionale aggiornamenti da GitHub (disattivato di default per privacy).
class UpdateService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);

    await _notificationsPlugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) async {
        final payload = response.payload;
        if (payload == null) return;
        final url = Uri.tryParse(payload);
        if (url != null && await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        }
      },
    );
  }

  static Future<void> checkForUpdates() async {
    if (!await Permission.notification.request().isGranted) return;

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final response = await http.get(
        Uri.parse(
          'https://api.github.com/repos/CatechHub-dev/CatechHub/releases/latest',
        ),
      );

      if (response.statusCode != 200) return;

      final data = json.decode(response.body) as Map<String, dynamic>;
      final latestVersion =
          (data['tag_name'] as String).replaceAll('v', '');
      final downloadUrl = data['html_url'] as String;

      if (_isVersionNewer(currentVersion, latestVersion)) {
        await _showUpdateNotification(latestVersion, downloadUrl);
      }
    } catch (e) {
      debugPrint('Errore controllo aggiornamenti: $e');
    }
  }

  static bool _isVersionNewer(String current, String latest) {
    final currentParts = current.split('.').map(int.parse).toList();
    final latestParts = latest.split('.').map(int.parse).toList();

    for (var i = 0; i < latestParts.length; i++) {
      if (i >= currentParts.length) return true;
      if (latestParts[i] > currentParts[i]) return true;
      if (latestParts[i] < currentParts[i]) return false;
    }
    return false;
  }

  static Future<void> _showUpdateNotification(
    String version,
    String url,
  ) async {
    const androidDetails = AndroidNotificationDetails(
      'update_channel_id',
      'Aggiornamenti App',
      channelDescription: 'Notifiche per i nuovi aggiornamenti di CatechHub',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const platformDetails = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      0,
      'Aggiornamento disponibile',
      'Versione $version. Tocca per maggiori informazioni.',
      platformDetails,
      payload: url,
    );
  }
}
