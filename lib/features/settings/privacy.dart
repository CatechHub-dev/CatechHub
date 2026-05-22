import 'package:flutter/material.dart';

import '../../shared/widgets/app_scaffold.dart';

class PrivacySecurityPage extends StatelessWidget {
  const PrivacySecurityPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Privacy e Sicurezza',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: const [

          /// HEADER
          _HeaderCard(),

          SizedBox(height: 16),

          /// INTRO
          _InfoCard(
            title: 'A cosa serve questa app',
            content:
                'Questa applicazione è progettata per supportare i catechisti '
                'nella gestione dei gruppi, delle presenze e delle attività pastorali. '
                'L’obiettivo è rendere più semplice, ordinata e sicura l’organizzazione delle comunità.',
            icon: Icons.church_rounded,
          ),

          SizedBox(height: 12),

          _InfoCard(
            title: 'Protezione dei dati',
            content:
                'Tutti i dati personali degli utenti vengono trattati con il massimo rispetto della privacy. '
                'Le informazioni sono salvate localmente sul dispositivo in un archivio Hive cifrato.',
            icon: Icons.lock_rounded,
          ),

          SizedBox(height: 12),

          _InfoCard(
            title: 'Crittografia',
            content:
                'I dati sensibili sono cifrati a riposo con Hive AES e la chiave viene custodita nel portachiavi sicuro del dispositivo. '
                'Questo riduce il rischio che le informazioni siano leggibili da terze parti non autorizzate.',
            icon: Icons.security_rounded,
          ),

          SizedBox(height: 12),

          _InfoCard(
            title: 'Standard di sicurezza',
            content:
                'L’app funziona offline e usa un PIN locale per sbloccare il registro. '
                'La protezione principale è legata al dispositivo e alla cifratura dell’archivio locale.',
            icon: Icons.verified_user_rounded,
          ),

          SizedBox(height: 12),

          _InfoCard(
            title: 'Accesso ai dati',
            content:
                'Solo utenti autorizzati possono accedere alle informazioni. '
                'I permessi vengono gestiti tramite ruoli (admin, catechista) e regole del database.',
            icon: Icons.admin_panel_settings_rounded,
          ),

          SizedBox(height: 24),

          Text(
            'La sicurezza dei dati è una priorità assoluta del sistema.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// =========================
/// HEADER
/// =========================
class _HeaderCard extends StatelessWidget {
  const _HeaderCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white,
            Colors.blue.shade50.withOpacity(0.4),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Row(
        children: [
          Icon(Icons.shield_rounded, color: Color(0xFF174A7E), size: 34),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Privacy e Sicurezza',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF174A7E),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// =========================
/// INFO CARD
/// =========================
class _InfoCard extends StatelessWidget {
  final String title;
  final String content;
  final IconData icon;

  const _InfoCard({
    required this.title,
    required this.content,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF174A7E).withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: const Color(0xFF174A7E)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
