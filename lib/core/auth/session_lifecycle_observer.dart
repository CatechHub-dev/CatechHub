import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../security/privacy_settings.dart';
import 'auth_provider.dart';

/// Blocca la sessione quando l'app non è più in primo piano (background o chiusura).
class SessionLifecycleObserver extends ConsumerStatefulWidget {
  const SessionLifecycleObserver({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SessionLifecycleObserver> createState() =>
      _SessionLifecycleObserverState();
}

class _SessionLifecycleObserverState
    extends ConsumerState<SessionLifecycleObserver>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!ref.read(privacySettingsProvider).lockOnBackground) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      ref.read(authStateProvider.notifier).lock();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
