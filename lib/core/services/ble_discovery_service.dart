import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'ble_association_service.dart';
import 'ble_constants.dart';

class BleDiscoveredDevice {
  final String id;
  final String name;
  final String? profileName;
  final String? role;

  BleDiscoveredDevice({
    required this.id,
    required this.name,
    this.profileName,
    this.role,
  });
}

class BleDiscoveryService {
  static const String serviceUuid = BleConstants.serviceUuid;

  static const MethodChannel _rfcommMethodChannel =
      MethodChannel('com.delelimed.catechhub/rfcomm_server');
  static const EventChannel _rfcommEventChannel =
      EventChannel('com.delelimed.catechhub/rfcomm_server_events');

  static final BleDiscoveryService _instance = BleDiscoveryService._internal();
  factory BleDiscoveryService() => _instance;
  BleDiscoveryService._internal();

  final BleAssociationService _associationService = BleAssociationService();

  bool _isActive = false;
  bool _isAssociationMode = false;
  String? _displayName;
  String? _myPairingPayload;

  final List<BleDiscoveredDevice> _foundDevices = [];
  final StreamController<List<BleDiscoveredDevice>> _devicesController =
      StreamController<List<BleDiscoveredDevice>>.broadcast();
  Stream<List<BleDiscoveredDevice>> get onDevicesChanged =>
      _devicesController.stream;

  final StreamController<String> _receivedPayloadController =
      StreamController<String>.broadcast();
  Stream<String> get onPairingPayloadReceived =>
      _receivedPayloadController.stream;

  // Sync communication streams
  final StreamController<String> _syncDataController =
      StreamController<String>.broadcast();
  Stream<String> get onSyncDataReceived => _syncDataController.stream;

  bool _isSyncConnected = false;
  bool get isSyncConnected => _isSyncConnected;

  StreamSubscription<BleDiscoveredAssociationDevice>? _associationSub;
  StreamSubscription<dynamic>? _rfcommEventSub;

  String? get currentPairingPayload => _myPairingPayload;
  bool get isAssociationMode => _isAssociationMode;

  bool _bleAvailable = true;
  bool get bleAvailable => _bleAvailable;
  final StreamController<bool> _bleAvailableController =
      StreamController<bool>.broadcast();
  Stream<bool> get onBleAvailableChanged => _bleAvailableController.stream;

  /// Check if the device supports BLE advertising/scanning.
  Future<bool> checkBleAvailable() async {
    _bleAvailable = await _associationService.isBleSupported();
    _bleAvailableController.add(_bleAvailable);
    return _bleAvailable;
  }

  /// Start discovery (BLE advertising + scanning for association).
  /// Falls back gracefully: without BLE, only RFCOMM server is started
  /// for manual sync with already-paired devices.
  Future<void> startDiscovery(String displayName,
      {String? pairingPayload}) async {
    if (_isActive) return;
    _isActive = true;
    _isAssociationMode = true;
    _displayName = displayName;
    _myPairingPayload = pairingPayload;
    _foundDevices.clear();
    _devicesController.add([]);

    try {
      final btEnabled = await _associationService.isBluetoothEnabled();
      if (!btEnabled) {
        throw Exception('Bluetooth non abilitato');
      }

      // Check BLE support
      _bleAvailable = await _associationService.isBleSupported();

      if (_bleAvailable) {
        await _associationService.startAdvertising(displayName, '');
        await _associationService.startScanning();

        _associationSub = _associationService.onDeviceDiscovered.listen((device) {
          final bleDevice = BleDiscoveredDevice(
            id: device.address,
            name: device.profileName,
            profileName: device.profileName,
            role: device.role,
          );
          if (!_foundDevices.any((d) => d.id == bleDevice.id)) {
            _foundDevices.add(bleDevice);
            _devicesController.add(List.from(_foundDevices));
          }
        });
      } else {
        debugPrint('BLE non supportato su questo dispositivo');
      }

      // Start RFCOMM server so pairing payloads can be exchanged
      if (pairingPayload != null) {
        try {
          await _rfcommMethodChannel.invokeMethod('startServer', {
            'response': pairingPayload,
          });
        } catch (e) {
          debugPrint('Avvio server RFCOMM per associazione: $e');
        }
      }
    } catch (e) {
      debugPrint('Errore avvio discovery: $e');
      _isActive = false;
      _isAssociationMode = false;
    }
  }

  Future<void> stopDiscovery() async {
    if (!_isActive) return;
    _isActive = false;

    _associationSub?.cancel();
    _associationSub = null;
    await _associationService.stopAdvertising();
    await _associationService.stopScanning();
    _isAssociationMode = false;

    _foundDevices.clear();
    _devicesController.add([]);
  }

  Future<void> updatePairingPayload(String payload) async {
    _myPairingPayload = payload;
  }

  /// Connect via RFCOMM and exchange pairing payloads (public keys).
  Future<String> connectAndExchangeKeys(
      BleDiscoveredDevice target, String localPayloadJson) async {
    final address = target.id;
    debugPrint('Connessione RFCOMM a $address');

    final response = await _rfcommMethodChannel.invokeMethod<String>(
      'connectAndExchange',
      {'address': address, 'payload': localPayloadJson},
    ).timeout(const Duration(seconds: 30));

    if (response == null || response.isEmpty) {
      throw Exception('Nessuna risposta dal dispositivo remoto');
    }
    return response;
  }

  Future<void> disconnect() async {
    _isSyncConnected = false;
    try {
      await _rfcommMethodChannel.invokeMethod('stopServer');
    } catch (_) {}
    _rfcommEventSub?.cancel();
    _rfcommEventSub = null;
  }

  /// Connect to a device for sync (RFCOMM).
  /// If [deviceId] is empty, starts the server (responder role).
  /// If [deviceId] is a MAC address, connects as client (initiator role).
  Future<void> connectForSync(String deviceId) async {
    try {
      if (deviceId.isEmpty) {
        await _rfcommMethodChannel.invokeMethod('startServer', {
          'response': '',
        });
      } else {
        await _rfcommMethodChannel.invokeMethod('connectForSync', {
          'address': deviceId,
        });
      }
      _isSyncConnected = true;

      _rfcommEventSub?.cancel();
      _rfcommEventSub = _rfcommEventChannel.receiveBroadcastStream().listen(
        (data) {
          if (data is List<int>) {
            final payload = utf8.decode(data);
            _syncDataController.add(payload);
          } else if (data is String) {
            _syncDataController.add(data);
          }
        },
        onError: (e) {
          debugPrint('Errore event channel RFCOMM sync: $e');
        },
      );
    } catch (e) {
      debugPrint('Errore connectForSync: $e');
      rethrow;
    }
  }

  /// Send data over the sync connection
  Future<void> sendData(String data) async {
    if (!_isSyncConnected) {
      throw Exception('Sync non connesso');
    }
    try {
      await _rfcommMethodChannel.invokeMethod('sendData', {
        'data': data,
      });
    } catch (e) {
      debugPrint('Errore sendData: $e');
      rethrow;
    }
  }

  /// Respond to an incoming sync request as peripheral
  Future<void> respondToSyncRequest(String responseJson) async {
    try {
      await _rfcommMethodChannel.invokeMethod('respondToSync', {
        'response': responseJson,
      });
    } catch (e) {
      debugPrint('Errore respondToSyncRequest: $e');
      rethrow;
    }
  }

  void dispose() {
    _associationSub?.cancel();
    _rfcommEventSub?.cancel();
    _devicesController.close();
    _receivedPayloadController.close();
    _syncDataController.close();
  }
}
