import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:wiredash/wiredash.dart';

import 'app/router.dart';
import 'core/auth/auth_provider.dart';
import 'core/auth/session_lifecycle_observer.dart';
import 'core/analytics/analytics_provider.dart';
import 'core/analytics/analytics_service.dart';
import 'core/analytics/event_tracking_service.dart';
import 'core/navigation/back_button_handler.dart';
import 'core/security/privacy_settings.dart';
import 'core/services/update_service.dart';
import 'core/storage/local_database.dart';

final navigatorKey = GlobalKey<NavigatorState>();

// Inizializza la navigatorKey per il servizio di aggiornamento
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
  if (privacy.checkUpdatesOnStart) {
    await UpdateService.checkForUpdates();
  }

  runApp(const ProviderScope(child: SessionLifecycleObserver(child: MyApp())));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  static const _wiredashProjectId = String.fromEnvironment(
    'WIREDASH_PROJECT_ID',
  );
  static const _wiredashSecret = String.fromEnvironment('WIREDASH_API_SECRET');

  bool get _wiredashConfigured =>
      _wiredashProjectId.isNotEmpty && _wiredashSecret.isNotEmpty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final router = ref.watch(appRouterProvider);
    final analyticsConsent = ref.watch(analyticsConsentProvider);
    final privacy = ref.watch(privacySettingsProvider);

    EventTrackingService.init(analyticsConsent);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showAnalyticsConsentIfNeeded(context, ref);
    });

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
        loading: () => const _LoadingScreen(),
        error: (err, _) => _ErrorScreen(message: 'Errore Auth: $err'),
      ),
    );

    if (privacy.allowRemoteFeedback && _wiredashConfigured) {
      app = Wiredash(
        projectId: _wiredashProjectId,
        secret: _wiredashSecret,
        child: app,
      );
    }

    return app;
  }

  void _showAnalyticsConsentIfNeeded(BuildContext context, WidgetRef ref) {
    final box = LocalDatabase.auth();
    final hasShownConsent = box.get('consent_shown', defaultValue: false);

    if (!hasShownConsent && context.mounted) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (context.mounted) {
          _showConsentDialog(context, ref);
          box.put('consent_shown', true);
        }
      });
    }
  }

  void _showConsentDialog(BuildContext context, WidgetRef ref) {
    showDialog(
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
