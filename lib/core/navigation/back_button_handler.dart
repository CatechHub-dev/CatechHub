import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

/// Widget che gestisce il comportamento del tasto indietro Android.
/// - Prima pressione sulla dashboard: mostra messaggio "Premi ancora per uscire"
/// - Seconda pressione entro 2 secondi: chiude l'app
class BackButtonHandler extends StatefulWidget {
  final Widget child;
  final GoRouter router;

  const BackButtonHandler({
    super.key,
    required this.child,
    required this.router,
  });

  @override
  State<BackButtonHandler> createState() => _BackButtonHandlerState();
}

class _BackButtonHandlerState extends State<BackButtonHandler> {
  DateTime? _lastBackPressed;
  static const int _backPressInterval = 2; // secondi

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _canPop(context),
      onPopInvoked: (didPop) {
        if (didPop) return;
        
        _handleBackPressed(context);
      },
      child: widget.child,
    );
  }

  bool _canPop(BuildContext context) {
    // Ottieni la posizione corrente dal router
    final location = widget.router.routeInformationProvider.value.uri.path;
    
    // Se non siamo sulla dashboard, permetti il pop normale
    if (location != '/') {
      return true;
    }
    
    // Sulla dashboard, non permettere il pop automatico
    return false;
  }

  void _handleBackPressed(BuildContext context) {
    // Ottieni la posizione corrente dal router
    final location = widget.router.routeInformationProvider.value.uri.path;
    
    // Se non siamo sulla dashboard, naviga normalmente
    if (location != '/') {
      widget.router.pop();
      return;
    }

    // Sulla dashboard: gestisci doppio tap per uscire
    final now = DateTime.now();
    
    if (_lastBackPressed == null || 
        now.difference(_lastBackPressed!) > const Duration(seconds: _backPressInterval)) {
      // Prima pressione o intervallo trascorso: mostra messaggio
      _lastBackPressed = now;
      _showExitSnackBar(context);
    } else {
      // Seconda pressione entro l'intervallo: chiude l'app
      _exitApp();
    }
  }

  void _showExitSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Premi ancora per uscire'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height - 100,
          left: 20,
          right: 20,
        ),
      ),
    );
  }

  void _exitApp() {
    // Chiude l'app
    SystemNavigator.pop();
  }
}