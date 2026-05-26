import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/analytics/analytics_provider.dart';
import '../../core/analytics/event_tracking_service.dart';
import '../../core/security/privacy_settings.dart';
import '../../shared/widgets/app_scaffold.dart';

class PrivacySecurityPage extends ConsumerWidget {
  const PrivacySecurityPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsConsent = ref.watch(analyticsConsentProvider);
    final privacy = ref.watch(privacySettingsProvider);
    final privacyNotifier = ref.read(privacySettingsProvider.notifier);

    return AppScaffold(
      title: 'Privacy e Sicurezza',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _HeaderCard(),
          const SizedBox(height: 16),
          const _SectionLabel('Come sono gestiti i dati'),
          const SizedBox(height: 8),
          const _InfoCard(
            title: 'Archivio locale cifrato',
            content:
                'Anagrafica ragazzi, presenze, programmazione, documenti e allegati '
                'sono salvati solo sul telefono in database Hive con crittografia AES-256. '
                'La chiave di cifratura resta nel portachiavi Android (Keystore), non nell\'app in chiaro.',
            icon: Icons.storage_rounded,
          ),
          const SizedBox(height: 10),
          const _InfoCard(
            title: 'Allegati foto e PDF',
            content:
                'I file non vanno in Galleria né in cartelle pubbliche: sono compressi, '
                'cifrati e conservati nella directory privata dell\'app (Application Support). '
                'Sono accessibili solo dopo lo sblocco con PIN o biometria.',
            icon: Icons.attach_file_rounded,
          ),
          const SizedBox(height: 10),
          const _InfoCard(
            title: 'PIN e sessione',
            content:
                'Il PIN non è salvato in chiaro: viene memorizzato solo l\'hash con salt. '
                'La sessione attiva resta in memoria; alla chiusura o in background (se abilitato) '
                'serve di nuovo l\'accesso.',
            icon: Icons.pin_rounded,
          ),
          const SizedBox(height: 10),
          const _InfoCard(
            title: 'Nessun cloud dei dati pastorali',
            content:
                'I dati del registro (ragazzi, appelli, riunioni) non vengono caricati su server. '
                'Restano sul dispositivo finché non li elimini tu dalle impostazioni.',
            icon: Icons.cloud_off_rounded,
          ),
          const SizedBox(height: 10),
          const _InfoCard(
            title: 'Connessioni di rete (opzionali)',
            content:
                'Per impostazione predefinita l\'app non contatta Internet all\'avvio. '
                'Solo se attivi le opzioni sotto può verificare aggiornamenti su GitHub o '
                'inviare feedback tramite Wiredash. I log di debug in release sono rimossi dalla build.',
            icon: Icons.wifi_off_rounded,
          ),
          const SizedBox(height: 10),
          const _InfoCard(
            title: 'GDPR e diritti',
            content:
                'In qualità di titolare del trattamento sul dispositivo puoi consultare, '
                'modificare o cancellare i dati in qualsiasi momento (anche in modo selettivo). '
                'La cancellazione è irreversibile e limitata al telefono.',
            icon: Icons.gavel_rounded,
          ),
          const SizedBox(height: 24),
          const _SectionLabel('Opzioni di sicurezza'),
          const SizedBox(height: 8),
          _ToggleCard(
            title: 'Blocca app in background',
            subtitle:
                'Richiede PIN o biometria quando esci dall\'app o la metti in secondo piano',
            icon: Icons.phonelink_lock_rounded,
            value: privacy.lockOnBackground,
            onChanged: privacyNotifier.setLockOnBackground,
          ),
          const SizedBox(height: 10),
          _ToggleCard(
            title: 'Blocca screenshot e registrazione',
            subtitle:
                'Impedisce catture schermo mentre l\'app è aperta (Android)',
            icon: Icons.screenshot_monitor_rounded,
            value: privacy.blockScreenshots,
            onChanged: privacyNotifier.setBlockScreenshots,
          ),
          const SizedBox(height: 10),
          _ToggleCard(
            title: 'Verifica aggiornamenti all\'avvio',
            subtitle:
                'Contatta GitHub per notificare nuove versioni (richiede Internet)',
            icon: Icons.system_update_rounded,
            value: privacy.checkUpdatesOnStart,
            onChanged: privacyNotifier.setCheckUpdatesOnStart,
          ),
          const SizedBox(height: 10),
          _ToggleCard(
            title: 'Feedback remoto (Wiredash)',
            subtitle:
                'Permette l\'invio volontario di segnalazioni con screenshot',
            icon: Icons.feedback_rounded,
            value: privacy.allowRemoteFeedback,
            onChanged: privacyNotifier.setAllowRemoteFeedback,
          ),
          const SizedBox(height: 10),
          _AnalyticsCard(
            analyticsEnabled: analyticsConsent,
            onChanged: (value) {
              ref.read(analyticsConsentProvider.notifier).setConsent(value);
              EventTrackingService.setEnabled(value);
            },
          ),
          const SizedBox(height: 20),
          ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.red.shade100),
            ),
            tileColor: Colors.red.shade50,
            leading: Icon(Icons.delete_forever_rounded, color: Colors.red.shade700),
            title: Text(
              'Cancella dati salvati',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red.shade800,
              ),
            ),
            subtitle: const Text('Elimina in modo selettivo anagrafica, presenze, ecc.'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/delete-data'),
          ),
          const SizedBox(height: 24),
          Text(
            'Build release: codice Dart offuscato e APK Android ottimizzato (R8).',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.8,
        color: Colors.grey.shade600,
      ),
    );
  }
}

class _ToggleCard extends StatelessWidget {
  const _ToggleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SwitchListTile(
        value: value,
        activeThumbColor: const Color(0xFF174A7E),
        onChanged: (v) => onChanged(v),
        secondary: Icon(icon, color: const Color(0xFF174A7E)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: TextStyle(color: Colors.grey.shade700)),
      ),
    );
  }
}

class _AnalyticsCard extends StatelessWidget {
  final bool analyticsEnabled;
  final ValueChanged<bool> onChanged;

  const _AnalyticsCard({
    required this.analyticsEnabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: SwitchListTile(
        value: analyticsEnabled,
        activeThumbColor: const Color(0xFF174A7E),
        onChanged: onChanged,
        secondary: const Icon(Icons.analytics_rounded, color: Color(0xFF174A7E)),
        title: const Text(
          'Statistiche uso locali',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          analyticsEnabled
              ? 'Solo log di debug in memoria durante l\'uso (non inviati automaticamente).'
              : 'Disattivato.',
          style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Colors.blue.shade50.withValues(alpha: 0.4)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
              'I tuoi dati restano sul dispositivo',
              style: TextStyle(
                fontSize: 17,
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
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF174A7E).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF174A7E), size: 22),
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
                    height: 1.45,
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
