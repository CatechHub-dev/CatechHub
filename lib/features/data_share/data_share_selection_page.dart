import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/auth/auth_service.dart';
import '../../core/services/ble_discovery_service.dart';
import '../../core/services/ble_pairing_service.dart';
import '../../core/services/ble_sync_manager.dart';
import '../../core/services/ble_sync_service.dart';
import '../../shared/widgets/app_scaffold.dart';

class DataShareSelectionPage extends StatefulWidget {
  const DataShareSelectionPage({super.key});

  @override
  State<DataShareSelectionPage> createState() => _DataShareSelectionPageState();
}

class _DataShareSelectionPageState extends State<DataShareSelectionPage> {
  final BlePairingService _pairingService = BlePairingService();
  final BleDiscoveryService _discoveryService = BleDiscoveryService();

  late final Stream<List<PairedBleDevice>> _pairedDevicesStream;
  late final Stream<List<BleSyncLog>> _syncLogsStream;

  bool _isBusy = false;
  String? _statusMessage;
  bool _statusIsError = false;

  bool _isDiscovering = false;
  bool _isPairingDevice = false;
  List<BleDiscoveredDevice> _foundDevices = [];
  StreamSubscription<List<BleDiscoveredDevice>>? _devicesSub;

  String? _syncingDeviceId;
  PairingDeviceRole _selectedRole = PairingDeviceRole.myDevice;

  bool _bleAvailable = true;

  @override
  void initState() {
    super.initState();
    _pairedDevicesStream = _pairingService.watchPairedDevices();
    _syncLogsStream = _pairingService.watchSyncLogs();
    _discoveryService.onBleAvailableChanged.listen((available) {
      if (mounted) setState(() => _bleAvailable = available);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _startDiscovery());
  }

  @override
  void dispose() {
    _devicesSub?.cancel();
    _discoveryService.stopDiscovery();
    super.dispose();
  }

  Future<String> _getDisplayName() async {
    final auth = AuthService();
    final user = auth.currentUser;
    return (user?['name'] as String?)?.trim() ?? 'Dispositivo';
  }

  Future<void> _startDiscovery() async {
    if (_isDiscovering) return;
    setState(() {
      _isDiscovering = true;
      _statusMessage = null;
      _foundDevices = [];
    });

    try {
      final available = await _discoveryService.checkBleAvailable();
      if (mounted) setState(() => _bleAvailable = available);

      final name = await _getDisplayName();
      final payload = await _pairingService.createPairingPayload(_selectedRole);
      _discoveryService.updatePairingPayload(payload.toJson());

      await _discoveryService.startDiscovery(name, pairingPayload: payload.toJson());

      _devicesSub?.cancel();
      _devicesSub = _discoveryService.onDevicesChanged.listen((devices) {
        if (mounted) setState(() => _foundDevices = devices);
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isDiscovering = false);
        _showMessage('Impossibile avviare la ricerca: $e', isError: true);
      }
    }
  }

  Future<void> _pairWithDevice(BleDiscoveredDevice device) async {
    setState(() => _isPairingDevice = true);

    try {
      final payload = await _pairingService.createPairingPayload(_selectedRole);
      _discoveryService.updatePairingPayload(payload.toJson());

      // RFCOMM connect → triggers Android PIN pairing, then exchanges payloads
      final remotePayloadJson = await _discoveryService.connectAndExchangeKeys(
        device,
        payload.toJson(),
      );

      final remotePayload = BlePairingPayload.fromJson(remotePayloadJson);

      // Verifica ruoli complementari
      if (!_areRolesConcordant(payload.role, remotePayload.role)) {
        if (mounted) {
          _showMessage(
            'Entrambi avete selezionato "${payload.role.title}". '
            'Uno deve essere "Mio dispositivo" e l\'altro "Altro catechista".',
            isError: true,
          );
        }
        return;
      }

      await _pairingService.pairFromPayload(
        remotePayloadJson,
        scannerBleId: device.id,
      );
      await _discoveryService.stopDiscovery();

      if (mounted) {
        setState(() {
          _isDiscovering = false;
          _foundDevices = [];
        });
        _showMessage('${device.name} associato come ${_selectedRole.title}!');

        _startDiscovery();
      }
    } catch (e) {
      final msg = e.toString().contains('Connetti')
          ? 'Associazione fallita: riprova.'
          : 'Associazione fallita: $e';
      _showMessage(msg, isError: true);
    } finally {
      if (mounted) setState(() => _isPairingDevice = false);
    }
  }

  bool _areRolesConcordant(PairingDeviceRole localRole, PairingDeviceRole remoteRole) {
    return localRole != remoteRole;
  }

  Future<void> _startSync() async {
    setState(() {
      _isBusy = true;
      _statusMessage = null;
    });

    try {
      final manager = BleSyncManager();
      await manager.performStartupSync(
        requestConsent: (device) => _requestSyncConsent(device),
      );
      _showMessage('Sincronizzazione completata');
    } catch (e) {
      _showMessage('Impossibile avviare la sincronizzazione BLE: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<bool> _requestSyncConsent(PairedBleDevice device) async {
    if (!mounted) return false;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(device.isOwnDevice
                ? 'Dispositivo trovato'
                : 'Sincronizzazione richiesta'),
            content: Text(
              device.isOwnDevice
                  ? 'Il tuo dispositivo "${device.displayName}" è nelle vicinanze. Sincronizzare?'
                  : '${device.displayName} (${device.role.title}) vuole sincronizzare i dati. Consentire?',
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
        ) ==
        true;
  }

  Future<void> _syncSingleDevice(PairedBleDevice device) async {
    if (_syncingDeviceId != null) return;
    setState(() => _syncingDeviceId = device.id);

    try {
      final syncService = BleSyncService();
      await syncService.syncWithDevice(device.bleRemoteId, device);
      if (mounted) _showMessage('Sync con ${device.displayName} completata');
    } catch (e) {
      if (mounted) _showMessage('Sync fallita: $e', isError: true);
    } finally {
      if (mounted) setState(() => _syncingDeviceId = null);
    }
  }

  Future<void> _deleteDevice(PairedBleDevice device) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Elimina dispositivo'),
        content: Text('Rimuovere "${device.displayName}" dai dispositivi associati?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    await _pairingService.deletePairedDevice(device.id);
    _showMessage('Dispositivo eliminato');
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _statusMessage = message;
      _statusIsError = isError;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Condivisione e backup',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SecurityCard(),
          const SizedBox(height: 20),
          if (_statusMessage != null) ...[
            _StatusCard(message: _statusMessage!, isError: _statusIsError),
            const SizedBox(height: 16),
          ],
          if (!_bleAvailable)
            _BleUnsupportedBanner(),
          const _SectionTitle(title: 'Associazione dispositivo'),
          const SizedBox(height: 12),
          Text(
            _bleAvailable
                ? "Entrambi i dispositivi devono essere in questa pagina. "
                    "La ricerca è automatica: quando trovi l'altro dispositivo, "
                    "seleziona il ruolo e tocca \"Associa\". "
                    "Dopo l'associazione Android con PIN, le chiavi pubbliche vengono scambiate in modo sicuro."
                : "Questo dispositivo non supporta il Bluetooth Low Energy (BLE). "
                    "Per associare un nuovo dispositivo, abbina i dispositivi dalle "
                    "Impostazioni Bluetooth Android, poi torna qui per la sincronizzazione.",
            style: TextStyle(color: Colors.grey.shade700, height: 1.4),
          ),
          const SizedBox(height: 16),
          _RoleSelector(
            selectedRole: _selectedRole,
            onChanged: (role) {
              setState(() => _selectedRole = role);
              _restartDiscovery();
            },
          ),
          const SizedBox(height: 12),
          _DiscoveryCard(
            isDiscovering: _isDiscovering,
            isPairingDevice: _isPairingDevice,
            deviceCount: _foundDevices.length,
            bleAvailable: _bleAvailable,
          ),
          if (_foundDevices.isNotEmpty) ...[
            const SizedBox(height: 12),
            ..._foundDevices.map(
              (device) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _DiscoveredDeviceTile(
                  device: device,
                  isBusy: _isPairingDevice,
                  onPair: () => _pairWithDevice(device),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          const _SectionTitle(title: 'Sincronizzazione'),
          const SizedBox(height: 12),
          _ActionCard(
            icon: Icons.sync_rounded,
            title: 'Avvia sincronizzazione manuale',
            subtitle: 'Sincronizza con tutti i dispositivi associati nelle vicinanze',
            color: const Color(0xFF174A7E),
            isLoading: _isBusy,
            onTap: _isBusy || _isDiscovering ? null : _startSync,
          ),
          const SizedBox(height: 24),
          const _SectionTitle(title: 'Dispositivi associati'),
          const SizedBox(height: 12),
          StreamBuilder<List<PairedBleDevice>>(
            stream: _pairedDevicesStream,
            builder: (context, snapshot) {
              final devices = snapshot.data ?? _pairingService.pairedDevices();
              if (devices.isEmpty) {
                return const _EmptyDevicesCard();
              }
              return Column(
                children: devices
                    .map(
                        (device) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _PairedDeviceTile(
                            device: device,
                            isSyncing: _syncingDeviceId == device.id,
                            onSync: () => _syncSingleDevice(device),
                            onDelete: () => _deleteDevice(device),
                          ),
                        ),
                      )
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 24),
          const _SectionTitle(title: 'Log sincronizzazioni'),
          const SizedBox(height: 12),
          StreamBuilder<List<BleSyncLog>>(
            stream: _syncLogsStream,
            builder: (context, snapshot) {
              final logs = snapshot.data ?? _pairingService.syncLogs();
              if (logs.isEmpty) {
                return const _EmptySyncLogCard();
              }

              final recentLogs = List<BleSyncLog>.from(logs)
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

              return Column(
                children: recentLogs.take(5).map(
                      (log) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _SyncLogTile(log: log),
                      ),
                    ).toList(),
              );
            },
          ),
          const SizedBox(height: 24),
          const _SectionTitle(title: 'Backup cifrato'),
          const SizedBox(height: 12),
          _ActionCard(
            icon: Icons.backup_rounded,
            title: 'Esporta o importa backup',
            subtitle: 'Gestisci file di backup cifrati dal sottomenù unico',
            color: Colors.teal,
            isLoading: false,
            onTap: () => context.go('/backup'),
          ),
        ],
      ),
    );
  }

  void _restartDiscovery() async {
    await _discoveryService.stopDiscovery();
    _startDiscovery();
  }
}

// ---- Widgets di supporto ----

class _SecurityCard extends StatelessWidget {
  const _SecurityCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF174A7E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.enhanced_encryption_rounded, color: Colors.white),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'I dati sono cifrati end-to-end e sincronizzati via Bluetooth (RFCOMM). '
              'La sincronizzazione funziona anche su dispositivi senza BLE.',
              style: TextStyle(color: Colors.white, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleSelector extends StatelessWidget {
  final PairingDeviceRole selectedRole;
  final ValueChanged<PairingDeviceRole> onChanged;

  const _RoleSelector({required this.selectedRole, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mi sto associando come:',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _RoleChip(
                  icon: Icons.devices_rounded,
                  label: 'Mio dispositivo',
                  subtitle: 'Sync automatica',
                  isSelected: selectedRole == PairingDeviceRole.myDevice,
                  onTap: () => onChanged(PairingDeviceRole.myDevice),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _RoleChip(
                  icon: Icons.person_add_alt_1_rounded,
                  label: 'Altro catechista',
                  subtitle: 'Consenso richiesto',
                  isSelected: selectedRole == PairingDeviceRole.catechist,
                  onTap: () => onChanged(PairingDeviceRole.catechist),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleChip({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = const Color(0xFF174A7E);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          color: isSelected ? color.withValues(alpha: 0.06) : Colors.grey.shade50,
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? color : Colors.grey, size: 26),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isSelected ? color : Colors.grey.shade700,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiscoveryCard extends StatelessWidget {
  final bool isDiscovering;
  final bool isPairingDevice;
  final int deviceCount;
  final bool bleAvailable;

  const _DiscoveryCard({
    required this.isDiscovering,
    required this.isPairingDevice,
    required this.deviceCount,
    required this.bleAvailable,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFF174A7E).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: isPairingDevice
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: const Color(0xFF174A7E),
                    ),
                  )
                : const Icon(Icons.bluetooth_searching_rounded, color: Color(0xFF174A7E)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  !bleAvailable
                      ? 'BLE non supportato'
                      : isDiscovering
                          ? 'Ricerca in corso...'
                          : 'Nessuna ricerca attiva',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  !bleAvailable
                      ? 'Usa la sincronizzazione manuale per i dispositivi associati'
                      : isDiscovering
                          ? 'Trovati $deviceCount dispositivi nelle vicinanze'
                          : 'Avvio discovery Bluetooth...',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscoveredDeviceTile extends StatelessWidget {
  final BleDiscoveredDevice device;
  final bool isBusy;
  final VoidCallback onPair;

  const _DiscoveredDeviceTile({
    required this.device,
    required this.isBusy,
    required this.onPair,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFF174A7E).withValues(alpha: 0.1),
            child: const Icon(Icons.devices_rounded, color: Color(0xFF174A7E)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(device.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(
                  device.role?.isNotEmpty == true
                      ? device.role == 'my_device'
                          ? 'Mio dispositivo'
                          : 'Altro catechista'
                      : 'In attesa di ruolo',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: isBusy ? null : onPair,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
            child: isBusy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Associa'),
          ),
        ],
      ),
    );
  }
}

class _PairedDeviceTile extends StatelessWidget {
  final PairedBleDevice device;
  final VoidCallback onDelete;
  final VoidCallback? onSync;
  final bool isSyncing;

  const _PairedDeviceTile({
    required this.device,
    required this.onDelete,
    this.onSync,
    this.isSyncing = false,
  });

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('dd/MM/yyyy HH:mm');
    final lastSync = device.lastSyncAt == null
        ? 'Mai sincronizzato'
        : 'Ultima sync ${formatter.format(device.lastSyncAt!.toLocal())}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFF174A7E).withValues(alpha: 0.1),
            child: Icon(
              device.isOwnDevice ? Icons.devices_rounded : Icons.person_rounded,
              color: const Color(0xFF174A7E),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(device.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(device.role.title, style: TextStyle(color: Colors.grey.shade700)),
                const SizedBox(height: 3),
                Text(
                  '$lastSync • ${device.fingerprint}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          if (onSync != null)
            IconButton(
              onPressed: isSyncing ? null : onSync,
              icon: isSyncing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync_rounded, color: Color(0xFF174A7E)),
              tooltip: 'Sincronizza ora',
            ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
          ),
        ],
      ),
    );
  }
}

class _EmptyDevicesCard extends StatelessWidget {
  const _EmptyDevicesCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Text('Nessun dispositivo associato.', style: TextStyle(color: Colors.grey.shade700)),
    );
  }
}

class _EmptySyncLogCard extends StatelessWidget {
  const _EmptySyncLogCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Text('Nessun log di sincronizzazione disponibile.', style: TextStyle(color: Colors.grey.shade700)),
    );
  }
}

class _SyncLogTile extends StatelessWidget {
  final BleSyncLog log;

  const _SyncLogTile({required this.log});

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('dd/MM/yyyy HH:mm');
    final title = switch (log.action) {
      'startup_sync' => 'Sync all\'avvio',
      'sync_started' => 'Sync avviata',
      'sync_completed' => 'Sync completata',
      'sync_failed' => 'Sync fallita',
      'sync_declined' => 'Sync rifiutata',
      'sync_skipped' => 'Sync saltata',
      'device_paired' => 'Dispositivo associato',
      _ => 'Dispositivo nelle vicinanze',
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
              Text(
                formatter.format(log.createdAt.toLocal()),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (log.deviceName.isNotEmpty)
            Text(
              '${log.deviceName} • ${log.role.title}',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          if (log.deviceName.isNotEmpty) const SizedBox(height: 4),
          Text(log.details, style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4)),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        letterSpacing: 1,
        color: Colors.grey.shade600,
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool isLoading;
  final VoidCallback? onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: isLoading
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: CircularProgressIndicator(strokeWidth: 2, color: color),
                    )
                  : Icon(icon, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}

class _BleUnsupportedBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Questo dispositivo non supporta BLE. '
              'L\'associazione tramite scoperta automatica non è disponibile. '
              'Puoi comunque sincronizzare i dispositivi già associati tramite Bluetooth classico.',
              style: TextStyle(color: Colors.orange.shade900, height: 1.35, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final String message;
  final bool isError;

  const _StatusCard({required this.message, required this.isError});

  @override
  Widget build(BuildContext context) {
    final color = isError ? Colors.red : Colors.green;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: TextStyle(color: color.shade700))),
        ],
      ),
    );
  }
}
