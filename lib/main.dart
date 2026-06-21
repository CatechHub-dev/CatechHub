import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:wiredash/wiredash.dart';
import 'package:device_info_plus/device_info_plus.dart';

import 'app/router.dart';
import 'core/auth/auth_provider.dart';
import 'core/auth/session_lifecycle_observer.dart';
import 'core/analytics/analytics_provider.dart';
import 'core/analytics/analytics_service.dart';
import 'core/analytics/event_tracking_service.dart';
import 'core/navigation/back_button_handler.dart';
import 'core/security/privacy_settings.dart';
import 'core/services/update_service.dart';
import 'core/services/ble_pairing_service.dart';
import 'core/services/ble_sync_manager.dart';
import 'core/storage/local_database.dart';

final navigatorKey = GlobalKey<NavigatorState>();

void _initUpdateServiceNavigatorKey() {
  UpdateService.setNavigatorKey(navigatorKey);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('it_IT', null);
  await LocalDatabase.init();
  await AnalyticsService.init();

  final privacy = PrivacySettingsNotifier.loadFromStorage();
  await PrivacySettingsNotifier.applyNativeOptions(privacy);

  _initUpdateServiceNavigatorKey();
  await UpdateService.initNotifications();
  await UpdateService.cleanupOldApks();
  if (privacy.checkUpdatesOnStart) {
    await UpdateService.checkForUpdates();
  }

  runApp(const ProviderScope(child: SessionLifecycleObserver(child: MyApp())));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  static const _wiredashProjectId = String.fromEnvironment('WIREDASH_PROJECT_ID');
  static const _wiredashSecret = String.fromEnvironment('WIREDASH_API_SECRET');
  static bool _initializationScheduled = false;

  bool get _wiredashConfigured =>
      _wiredashProjectId.isNotEmpty && _wiredashSecret.isNotEmpty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final router = ref.watch(appRouterProvider);
    final analyticsConsent = ref.watch(analyticsConsentProvider);
    final privacy = ref.watch(privacySettingsProvider);

    EventTrackingService.init(analyticsConsent);

    if (!_initializationScheduled) {
      _initializationScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final navContext = navigatorKey.currentContext;
        if (navContext != null && navContext.mounted) {
          // Eseguiamo la catena di inizializzazione in modo sequenziale controllato
          _runSequentialInitialization(navContext, ref, privacy);
        }
      });
    }

    final isLoginRoute = router.routeInformationProvider.value.uri.path.startsWith('/login');
    Widget app = MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF174A7E)),
        scaffoldBackgroundColor: const Color(0xFFF5F7FB),
      ),
      navigatorKey: navigatorKey,
      home: authState.when(
        data: (_) {
          return BackButtonHandler(
            router: router,
            child: Router(
              routerDelegate: router.routerDelegate,
              routeInformationParser: router.routeInformationParser,
              routeInformationProvider: router.routeInformationProvider,
            ),
          );
        },
        loading: () => isLoginRoute
            ? BackButtonHandler(
                router: router,
                child: Router(
                  routerDelegate: router.routerDelegate,
                  routeInformationParser: router.routeInformationParser,
                  routeInformationProvider: router.routeInformationProvider,
                ),
              )
            : const _LoadingScreen(),
        error: (err, _) => _ErrorScreen(message: 'Errore Auth: $err'),
      ),
    );

    if (privacy.allowRemoteFeedback && _wiredashConfigured) {
      app = Wiredash(
        projectId: _wiredashProjectId,
        secret: _wiredashSecret,
        psOptions: const PsOptions(
          frequency: Duration(days: 30),
          initialDelay: Duration(days: 7),
          minimumAppStarts: 0,
        ),
        child: app,
      );
    }

    return app;
  }

  /// Gestisce le richieste e le attivazioni una dopo l'altra,
  /// evitando di intasare il thread nativo hardware all'avvio.
  Future<void> _runSequentialInitialization(
    BuildContext context,
    WidgetRef ref,
    PrivacySettings privacy,
  ) async {
    try {
      // 1. Consenso Analytics (Mostra Dialog se necessario ed attende la chiusura)
      await _showAnalyticsConsentIfNeeded(context, ref);
      if (!context.mounted) return;

      // 2. Richiesta Notifiche (Attende l'esito o la chiusura del Dialog)
      await _requestNotificationPermissionIfNeeded(context);
      if (!context.mounted) return;

      // 3. Richiesta Fotocamera (Attende l'esito o la chiusura del Dialog)
      await _requestCameraPermissionIfNeeded(context);
      if (!context.mounted) return;

      // 4. Richiesta Bluetooth (Attende l'esito dei permessi nativi)
      await _requestBluetoothPermissionIfNeeded(context);
      if (!context.mounted) return;

      // 5. Survey Wiredash periodico
      _showMonthlyRandomPromoterSurvey(context, privacy);

      // 6. INFINE, avviamo il servizio di sincronizzazione automatica BLE.
      // Essendo l'ultimo step, l'hardware è rilassato e i permessi sono già definiti.
      _startBleAutoSync(context);
    } catch (e) {
      debugPrint('Errore durante l\'inizializzazione sequenziale: $e');
    }
  }

  void _startBleAutoSync(BuildContext context) {
    unawaited(Future(() async {
      try {
        final syncManager = BleSyncManager();
        await syncManager.performStartupSync(
          requestConsent: (device) async {
            if (!context.mounted) return false;
            final allowed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Sincronizzazione richiesta'),
                content: Text(
                  '${device.displayName} (${device.role.title}) è nelle vicinanze. '
                  'Vuoi sincronizzare i dati?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Nega'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Consenti'),
                  ),
                ],
              ),
            );
            return allowed == true;
          },
        );
      } catch (e) {
        debugPrint('BLE sync error: $e');
      }
    }));
  }

  Future<void> _showAnalyticsConsentIfNeeded(BuildContext context, WidgetRef ref) async {
    final box = LocalDatabase.auth();
    final hasShownConsent = box.get('consent_shown', defaultValue: false);

    if (!hasShownConsent && context.mounted) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (context.mounted) {
        await _showConsentDialog(context, ref);
        await box.put('consent_shown', true);
      }
    }
  }

  Future<void> _requestNotificationPermissionIfNeeded(BuildContext context) async {
    final authBox = LocalDatabase.auth();
    final notificationRequested =
        authBox.get('notification_permission_requested', defaultValue: false) as bool;

    final status = await UpdateService.notificationPermissionStatus();
    if (status == PermissionStatus.granted || status == PermissionStatus.limited) {
      return;
    }

    if (!context.mounted) return;

    if (status == PermissionStatus.permanentlyDenied || status == PermissionStatus.restricted) {
      await _showNotificationSettingsDialog(context);
      return;
    }

    final shouldRequest = !notificationRequested || status == PermissionStatus.denied;
    if (!shouldRequest) return;

    final confirmation = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Permesso notifiche'),
        content: const Text(
          'CatechHub usa le notifiche per avvisarti degli aggiornamenti e delle novità. '
          'Vuoi permettere all\'app di inviarti notifiche?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Rifiuta'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Consenti'),
          ),
        ],
      ),
    );

    await authBox.put('notification_permission_requested', true);
    if (confirmation != true || !context.mounted) return;

    final newStatus = await UpdateService.requestNotificationPermission();
    if (newStatus == PermissionStatus.granted || newStatus == PermissionStatus.limited) {
      return;
    }

    if ((newStatus == PermissionStatus.permanentlyDenied || newStatus == PermissionStatus.restricted) && context.mounted) {
      await _showNotificationSettingsDialog(context);
    }
  }

  Future<void> _requestCameraPermissionIfNeeded(BuildContext context) async {
    final authBox = LocalDatabase.auth();
    final cameraRequested =
        authBox.get('camera_permission_requested', defaultValue: false) as bool;

    final status = await Permission.camera.status;
    if (status.isGranted) {
      return;
    }

    if (!context.mounted) return;

    if (status.isPermanentlyDenied || status.isRestricted) {
      await _showCameraSettingsDialog(context);
      return;
    }

    final shouldRequest = !cameraRequested || status.isDenied;
    if (!shouldRequest) return;

    final confirmation = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Permesso fotocamera'),
        content: const Text(
          'CatechHub usa la fotocamera per scansionare i codici QR '
          'per il backup/ripristino dei dati. '
          'Vuoi permettere all\'app di accedere alla fotocamera?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Rifiuta'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(),
            child: const Text('Consenti'),
          ),
        ],
      ),
    );

    await authBox.put('camera_permission_requested', true);
    if (confirmation != true || !context.mounted) return;

    final newStatus = await Permission.camera.request();
    if (newStatus.isGranted) {
      return;
    }

    if ((newStatus.isPermanentlyDenied || newStatus.isRestricted) && context.mounted) {
      await _showCameraSettingsDialog(context);
    }
  }

  Future<void> _requestBluetoothPermissionIfNeeded(BuildContext context) async {
    final authBox = LocalDatabase.auth();

    final permissions = <Permission>[];
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final sdkInt = androidInfo.version.sdkInt;
      if (sdkInt >= 31) {
        permissions.addAll([
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.bluetoothAdvertise,
        ]);
      } else {
        permissions.addAll([
          Permission.location,
        ]);
      }
    } else {
      permissions.add(Permission.bluetooth);
    }

    final statuses = await permissions.request();
    final allGranted = statuses.values.every(
      (status) => status == PermissionStatus.granted || status == PermissionStatus.limited,
    );
    if (allGranted) {
      await authBox.put('bluetooth_permission_requested', true);
      return;
    }

    if (!context.mounted) return;
    final anyDenied = statuses.values.any((status) => status == PermissionStatus.denied);
    final anyPermanentlyDenied = statuses.values.any(
      (status) => status == PermissionStatus.permanentlyDenied || status == PermissionStatus.restricted,
    );

    await authBox.put('bluetooth_permission_requested', true);
    if (anyPermanentlyDenied) {
      await _showBluetoothSettingsDialog(context);
      return;
    }

    if (!anyDenied || !context.mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Permesso Bluetooth'),
        content: const Text(
          'CatechHub usa il Bluetooth per trovare e sincronizzare i dispositivi associati. '
          'Consenti l’accesso al Bluetooth per funzionare correttamente?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sì'),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    final againStatuses = await permissions.request();
    final grantedAgain = againStatuses.values.every(
      (status) => status == PermissionStatus.granted || status == PermissionStatus.limited,
    );
    if (grantedAgain) return;

    if (againStatuses.values.any((status) =>
            status == PermissionStatus.permanentlyDenied || status == PermissionStatus.restricted) &&
        context.mounted) {
      await _showBluetoothSettingsDialog(context);
    }
  }

  Future<void> _showBluetoothSettingsDialog(BuildContext context) async {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Bluetooth disattivato o non autorizzato'),
        content: const Text(
          'Per sincronizzare i dispositivi associati, devi abilitare il Bluetooth '
          'e concedere le autorizzazioni nelle impostazioni del dispositivo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Chiudi'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Apri impostazioni'),
          ),
        ],
      ),
    );
  }

  Future<void> _showNotificationSettingsDialog(BuildContext context) async {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Notifiche disattivate'),
        content: const Text(
          'Le notifiche non sono abilitate. Per ricevere gli avvisi di aggiornamento, '
          'devi attivare le notifiche nelle impostazioni del sistema.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Chiudi'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              UpdateService.openNotificationSettings();
            },
            child: const Text('Apri impostazioni'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCameraSettingsDialog(BuildContext context) async {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Fotocamera non autorizzata'),
        content: const Text(
          'Per scansionare i codici QR e associare dispositivi, '
          'devi concedere l\'autorizzazione alla fotocamera nelle impostazioni del dispositivo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Chiudi'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Apri impostazioni'),
          ),
        ],
      ),
    );
  }

  void _showMonthlyRandomPromoterSurvey(BuildContext context, PrivacySettings privacy) {
    if (!privacy.allowRemoteFeedback || !_wiredashConfigured || !context.mounted) {
      return;
    }

    final box = LocalDatabase.auth();
    final now = DateTime.now().toUtc();
    final nextSurveyKey = 'wiredash_promoter_next_date';
    final nextSurveyValue = box.get(nextSurveyKey) as String?;
    DateTime? nextSurveyDate;

    if (nextSurveyValue != null) {
      nextSurveyDate = DateTime.tryParse(nextSurveyValue)?.toUtc();
    }

    if (nextSurveyDate == null) {
      final scheduledDate = now.add(Duration(days: 7 + Random().nextInt(24)));
      box.put(nextSurveyKey, scheduledDate.toIso8601String());
      return;
    }

    if (now.isBefore(nextSurveyDate)) {
      return;
    }

    try {
      Wiredash.of(context).showPromoterSurvey(inheritMaterialTheme: true);
      final nextScheduledDate = now.add(Duration(days: 30 + Random().nextInt(15)));
      box.put(nextSurveyKey, nextScheduledDate.toIso8601String());
    } catch (_) {}
  }

  Future<void> _showConsentDialog(BuildContext context, WidgetRef ref) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Analisi e Feedback'),
        content: const Text(
          'Desideri permettere a CatechHub di raccogliere dati anonimi '
          'sulla tua esperienza utente? Questo ci aiuta a migliorare l\'app.\n\n'
          'Puoi cambiare questa preferenza in qualsiasi momento dalle impostazioni.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(analyticsConsentProvider.notifier).setConsent(false);
              EventTrackingService.setEnabled(false);
              Navigator.pop(context);
            },
            child: const Text('Rifiuta'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(analyticsConsentProvider.notifier).setConsent(true);
              EventTrackingService.setEnabled(true);
              Navigator.pop(context);
            },
            child: const Text('Accetta'),
          ),
        ],
      ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator(color: Color(0xFF174A7E))),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  final String message;
  const _ErrorScreen({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}