import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../storage/local_database.dart';
import 'ble_discovery_service.dart';
import 'ble_pairing_service.dart';
import 'ble_sync_service.dart';

class BleSyncManager {
  final BlePairingService _pairingService;
  final BleSyncService _syncService;
  final BleDiscoveryService _discoveryService;

  bool _isRunning = false;
  StreamSubscription<String>? _incomingSub;

  BleSyncManager({
    BlePairingService? pairingService,
    BleSyncService? syncService,
    BleDiscoveryService? discoveryService,
  })  : _pairingService = pairingService ?? BlePairingService(),
        _syncService = syncService ?? BleSyncService(),
        _discoveryService = discoveryService ?? BleDiscoveryService();

  Future<void> performStartupSync({
    Future<bool> Function(PairedBleDevice)? requestConsent,
  }) async {
    if (_isRunning) return;
    _isRunning = true;

    try {
      final devices = _pairingService.pairedDevices();
      if (devices.isEmpty) {
        _isRunning = false;
        return;
      }

      await _logStartup(devices.length);
      final localId = await _pairingService.getLocalDeviceId();

      // Start server for incoming connections
      await _discoveryService.connectForSync('');

      // Wire up consent requests
      final consentSub = _syncService.onConsentRequired.listen((req) async {
        final device = devices.cast<PairedBleDevice?>().firstWhere(
          (d) => d!.id == req.remoteDeviceId || d.displayName == req.remoteDeviceName,
          orElse: () => null,
        );
        if (device == null) {
          req.completer.complete(false);
          return;
        }
        bool allowed = false;
        if (requestConsent != null) {
          allowed = await requestConsent(device);
        }
        req.completer.complete(allowed);
      });

      // Listen for incoming SYNC_REQ on the shared stream.
      _incomingSub = _discoveryService.onSyncDataReceived.listen((raw) {
        try {
          final msg = jsonDecode(raw) as Map<String, dynamic>;
          if (msg['type'] == 'SYNC_REQ') {
            final remoteDeviceId = msg['deviceId'] as String? ?? '';
            final device = devices.cast<PairedBleDevice?>().firstWhere(
              (d) => d!.id == remoteDeviceId,
              orElse: () => null,
            );
            if (device != null) {
              unawaited(_syncService.handleIncomingSync(device, msg));
            }
          }
        } catch (_) {}
      });

      // For each device with higher localId, initiate sync
      for (final device in devices) {
        if (device.bleRemoteId.isEmpty) continue;
        final isInitiator = localId.compareTo(device.id) > 0;
        if (isInitiator) {
          await _syncService.syncWithDevice(device.bleRemoteId, device);
        }
      }

      // Wait for incoming syncs to complete
      await Future.delayed(const Duration(seconds: 20));
      await _incomingSub?.cancel();
      await consentSub.cancel();
      await _discoveryService.disconnect();
    } finally {
      _isRunning = false;
    }
  }

  /// Manually sync with a specific device
  Future<bool> syncWithDevice(PairedBleDevice device) async {
    if (device.bleRemoteId.isEmpty) return false;
    return await _syncService.syncWithDevice(device.bleRemoteId, device);
  }

  Future<void> _logStartup(int deviceCount) async {
    await _pairingService.addSyncLog(BleSyncLog(
      id: LocalDatabase.newId('ble_sync'),
      deviceId: '',
      deviceName: 'Locale',
      role: PairingDeviceRole.myDevice,
      createdAt: DateTime.now().toUtc(),
      action: 'startup_sync',
      details: 'Sync avvio: $deviceCount dispositivi associati',
    ));
  }
}
