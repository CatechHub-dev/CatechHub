import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class BleDiscoveredAssociationDevice {
  final String address;
  final String profileName;
  final String role;
  final int rssi;

  BleDiscoveredAssociationDevice({
    required this.address,
    required this.profileName,
    required this.role,
    required this.rssi,
  });

  factory BleDiscoveredAssociationDevice.fromMap(Map<String, dynamic> map) {
    return BleDiscoveredAssociationDevice(
      address: map['address'] as String? ?? '',
      profileName: map['profileName'] as String? ?? 'Sconosciuto',
      role: map['role'] as String? ?? '',
      rssi: map['rssi'] as int? ?? 0,
    );
  }
}

class BleAssociationService {
  static const MethodChannel _methodChannel =
      MethodChannel('com.delelimed.catechhub/ble_association');
  static const EventChannel _eventChannel =
      EventChannel('com.delelimed.catechhub/ble_association_events');

  static final BleAssociationService _instance = BleAssociationService._internal();
  factory BleAssociationService() => _instance;
  BleAssociationService._internal();

  bool _isAdvertising = false;
  bool _isScanning = false;

  final StreamController<BleDiscoveredAssociationDevice> _discoveredController =
      StreamController<BleDiscoveredAssociationDevice>.broadcast();
  Stream<BleDiscoveredAssociationDevice> get onDeviceDiscovered =>
      _discoveredController.stream;

  StreamSubscription<dynamic>? _eventSub;

  bool get isAdvertising => _isAdvertising;
  bool get isScanning => _isScanning;

  Future<bool> isBluetoothEnabled() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('isBluetoothEnabled');
      return result ?? false;
    } catch (e) {
      debugPrint('Errore controllo Bluetooth: $e');
      return false;
    }
  }

  Future<bool> isBleSupported() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('isBleSupported');
      return result ?? false;
    } catch (e) {
      debugPrint('Errore controllo BLE support: $e');
      return false;
    }
  }

  Future<bool> startAdvertising(String profileName, String role) async {
    if (_isAdvertising) return true;

    try {
      final result = await _methodChannel.invokeMethod<bool>('startAdvertising', {
        'profileName': profileName,
        'role': role,
      });

      if (result == true) {
        _isAdvertising = true;
        debugPrint('BLE advertising avviato: $profileName ($role)');
      }
      return result ?? false;
    } catch (e) {
      debugPrint('Errore avvio advertising: $e');
      return false;
    }
  }

  Future<void> stopAdvertising() async {
    if (!_isAdvertising) return;

    try {
      await _methodChannel.invokeMethod('stopAdvertising');
      _isAdvertising = false;
      debugPrint('BLE advertising fermato');
    } catch (e) {
      debugPrint('Errore stop advertising: $e');
    }
  }

  Future<bool> startScanning() async {
    if (_isScanning) return true;

    try {
      final result = await _methodChannel.invokeMethod<bool>('startScanning');

      if (result == true) {
        _isScanning = true;
        _eventSub?.cancel();
        _eventSub = _eventChannel.receiveBroadcastStream().listen(
          (data) {
            if (data is Map) {
              final device = BleDiscoveredAssociationDevice.fromMap(Map<String, dynamic>.from(data));
              _discoveredController.add(device);
              debugPrint('Dispositivo trovato: ${device.profileName} (${device.role})');
            }
          },
          onError: (e) {
            debugPrint('Errore scanning BLE: $e');
          },
        );
        debugPrint('BLE scanning avviato');
      }
      return result ?? false;
    } catch (e) {
      debugPrint('Errore avvio scanning: $e');
      return false;
    }
  }

  Future<void> stopScanning() async {
    if (!_isScanning) return;

    try {
      await _methodChannel.invokeMethod('stopScanning');
      _isScanning = false;
      _eventSub?.cancel();
      _eventSub = null;
      debugPrint('BLE scanning fermato');
    } catch (e) {
      debugPrint('Errore stop scanning: $e');
    }
  }

  void dispose() {
    stopAdvertising();
    stopScanning();
    _discoveredController.close();
  }
}
