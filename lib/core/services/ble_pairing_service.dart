import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import '../storage/local_database.dart';
import 'keystore_service.dart';

PairingResult _processPairingPayloadIsolate(PairingInput input) {
  try {
    final payload = BlePairingPayload.fromJson(input.payloadJson);
    if (payload.app != 'CatechHub' || payload.publicKey.isEmpty) {
      return PairingResult(error: 'Dati di pairing non validi');
    }
    if (DateTime.now().toUtc().isAfter(payload.expiresAt.toUtc())) {
      return PairingResult(error: 'Dati di pairing scaduti');
    }

    final fingerprint = BlePairingService.publicKeyFingerprint(payload.publicKey);
    if (fingerprint != payload.fingerprint) {
      return PairingResult(error: 'Impronta della chiave non valida');
    }

    final device = PairedBleDevice(
      id: payload.deviceId,
      hardwareId: payload.hardwareId,
      displayName: payload.deviceName,
      role: payload.role,
      publicKey: payload.publicKey,
      fingerprint: fingerprint,
      pairedAt: DateTime.now().toUtc(),
      keyCreatedAt: payload.keyCreatedAt.toUtc(),
      bleRemoteId: input.scannerBleId ?? '',
    );

    return PairingResult(device: device, deviceMap: device.toMap());
  } catch (e) {
    return PairingResult(error: 'Errore durante il processing: $e');
  }
}

class PairingInput {
  final String payloadJson;
  final String? scannerBleId;
  PairingInput(this.payloadJson, {this.scannerBleId});
}

class PairingResult {
  final PairedBleDevice? device;
  final String? error;
  final Map<String, dynamic>? deviceMap;
  PairingResult({this.device, this.error, this.deviceMap});
}

enum PairingDeviceRole { myDevice, catechist }

extension PairingDeviceRoleLabel on PairingDeviceRole {
  String get storageValue {
    switch (this) {
      case PairingDeviceRole.myDevice:
        return 'my_device';
      case PairingDeviceRole.catechist:
        return 'catechist';
    }
  }

  String get title {
    switch (this) {
      case PairingDeviceRole.myDevice:
        return 'Mio dispositivo';
      case PairingDeviceRole.catechist:
        return 'Altro Catechista';
    }
  }
}

class PairedBleDevice {
  final String id;
  final String hardwareId;
  final String displayName;
  final PairingDeviceRole role;
  final String publicKey;
  final String fingerprint;
  final DateTime pairedAt;
  final DateTime keyCreatedAt;
  final DateTime? lastSyncAt;
  final String bleRemoteId;

  const PairedBleDevice({
    required this.id,
    required this.hardwareId,
    required this.displayName,
    required this.role,
    required this.publicKey,
    required this.fingerprint,
    required this.pairedAt,
    required this.keyCreatedAt,
    this.lastSyncAt,
    this.bleRemoteId = '',
  });

  bool get isOwnDevice => role == PairingDeviceRole.myDevice;

  bool get needsConsent => role == PairingDeviceRole.catechist;

  Map<String, dynamic> toMap() => {
    'id': id,
    'hardwareId': hardwareId,
    'displayName': displayName,
    'role': role.storageValue,
    'publicKey': publicKey,
    'fingerprint': fingerprint,
    'pairedAt': pairedAt.toIso8601String(),
    'keyCreatedAt': keyCreatedAt.toIso8601String(),
    'lastSyncAt': lastSyncAt?.toIso8601String(),
    'bleRemoteId': bleRemoteId,
  };

  factory PairedBleDevice.fromMap(Map<String, dynamic> map) {
    return PairedBleDevice(
      id: map['id'] as String? ?? '',
      hardwareId: map['hardwareId'] as String? ?? '',
      displayName: map['displayName'] as String? ?? 'Dispositivo',
      role: _roleFromStorage(map['role'] as String?),
      publicKey: map['publicKey'] as String? ?? '',
      fingerprint: map['fingerprint'] as String? ?? '',
      pairedAt:
          DateTime.tryParse(map['pairedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      keyCreatedAt:
          DateTime.tryParse(map['keyCreatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      lastSyncAt: DateTime.tryParse(map['lastSyncAt'] as String? ?? ''),
      bleRemoteId: map['bleRemoteId'] as String? ?? '',
    );
  }

  static PairingDeviceRole _roleFromStorage(String? value) {
    return PairingDeviceRole.values.firstWhere(
      (role) => role.storageValue == value,
      orElse: () => PairingDeviceRole.catechist,
    );
  }

  PairedBleDevice copyWith({
    DateTime? lastSyncAt,
    String? bleRemoteId,
  }) {
    return PairedBleDevice(
      id: id,
      hardwareId: hardwareId,
      displayName: displayName,
      role: role,
      publicKey: publicKey,
      fingerprint: fingerprint,
      pairedAt: pairedAt,
      keyCreatedAt: keyCreatedAt,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      bleRemoteId: bleRemoteId ?? this.bleRemoteId,
    );
  }
}

class BlePairingPayload {
  final int version;
  final String app;
  final String deviceId;
  final String hardwareId;
  final String deviceName;
  final String publicKey;
  final String fingerprint;
  final PairingDeviceRole role;
  final DateTime keyCreatedAt;
  final DateTime expiresAt;

  const BlePairingPayload({
    required this.version,
    required this.app,
    required this.deviceId,
    required this.hardwareId,
    required this.deviceName,
    required this.publicKey,
    required this.fingerprint,
    required this.role,
    required this.keyCreatedAt,
    required this.expiresAt,
  });

  String toJson() => jsonEncode({
    'version': version,
    'app': app,
    'deviceId': deviceId,
    'hardwareId': hardwareId,
    'deviceName': deviceName,
    'publicKey': publicKey,
    'fingerprint': fingerprint,
    'role': role.storageValue,
    'keyCreatedAt': keyCreatedAt.toIso8601String(),
    'expiresAt': expiresAt.toIso8601String(),
  });

  factory BlePairingPayload.fromJson(String source) {
    final map = jsonDecode(source) as Map<String, dynamic>;
    return BlePairingPayload(
      version: map['version'] as int? ?? 1,
      app: map['app'] as String? ?? '',
      deviceId: map['deviceId'] as String? ?? '',
      hardwareId: map['hardwareId'] as String? ?? '',
      deviceName: map['deviceName'] as String? ?? 'Dispositivo',
      publicKey: map['publicKey'] as String? ?? '',
      fingerprint: map['fingerprint'] as String? ?? '',
      role: PairedBleDevice._roleFromStorage(map['role'] as String?),
      keyCreatedAt:
          DateTime.tryParse(map['keyCreatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      expiresAt:
          DateTime.tryParse(map['expiresAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class BlePairingService {
  static const identityAlias = 'catechhub_ble_identity_v1';
  static const _identityAlias = identityAlias;
  static const _metadataKey = 'ble_identity_metadata';
  static const _deviceIdKey = 'ble_local_device_id';
  static const _keyRotationDays = 30;

  final KeystoreService _keystore;

  BlePairingService({KeystoreService? keystore})
    : _keystore = keystore ?? KeystoreService();

  Future<BlePairingPayload> createPairingPayload(PairingDeviceRole role) async {
    final publicKey = await _ensureFreshLocalKeyPair();
    final now = DateTime.now().toUtc();
    final deviceName = await _localDeviceName();

    return BlePairingPayload(
      version: 1,
      app: 'CatechHub',
      deviceId: await _localDeviceId(),
      hardwareId: await _localHardwareId(),
      deviceName: deviceName,
      publicKey: publicKey,
      fingerprint: publicKeyFingerprint(publicKey),
      role: role,
      keyCreatedAt: await _localKeyCreatedAt(),
      expiresAt: now.add(const Duration(minutes: 10)),
    );
  }

  Future<void> pairFromPayload(String payloadJson, {String? scannerBleId}) async {
    final result = await compute(
      _processPairingPayloadIsolate,
      PairingInput(payloadJson, scannerBleId: scannerBleId),
    );

    if (result.error != null) {
      throw Exception(result.error);
    }

    final device = result.device!;
    final deviceMap = result.deviceMap!;

    await LocalDatabase.pairedDevices().put(device.id, deviceMap);

    final log = BleSyncLog(
      id: LocalDatabase.newId('ble_sync'),
      deviceId: device.id,
      deviceName: device.displayName,
      role: device.role,
      createdAt: DateTime.now().toUtc(),
      action: 'device_paired',
      details: 'Dispositivo associato: ${device.displayName}',
    );
    await LocalDatabase.syncLogs().put(log.id, log.toMap());
  }

  Stream<List<PairedBleDevice>> watchPairedDevices() {
    return LocalDatabase.watchList(
      LocalDatabase.pairedDevices(),
      (_, data) => PairedBleDevice.fromMap(data),
    );
  }

  List<PairedBleDevice> pairedDevices() {
    return LocalDatabase.values(
      LocalDatabase.pairedDevices(),
      (_, data) => PairedBleDevice.fromMap(data),
    );
  }

  Stream<List<BleSyncLog>> watchSyncLogs() {
    return LocalDatabase.watchList(
      LocalDatabase.syncLogs(),
      (id, data) => BleSyncLog.fromMap(data, id),
    );
  }

  List<BleSyncLog> syncLogs() {
    return LocalDatabase.values(
      LocalDatabase.syncLogs(),
      (id, data) => BleSyncLog.fromMap(data, id),
    );
  }

  Future<void> deletePairedDevice(String id) async {
    await LocalDatabase.pairedDevices().delete(id);
  }

  Future<void> updatePairedDevice(String id, PairedBleDevice updated) async {
    await LocalDatabase.pairedDevices().put(id, updated.toMap());
  }

  Future<String> _ensureFreshLocalKeyPair() async {
    final exists = await _keystore.keyExists(_identityAlias);
    final createdAt = await _localKeyCreatedAt();
    final expired =
        DateTime.now().toUtc().difference(createdAt).inDays >= _keyRotationDays;

    if (!exists || expired) {
      if (exists) await _keystore.deleteKey(_identityAlias);
      final publicKey = await _keystore.generateKeyPair(_identityAlias);
      await LocalDatabase.auth().put(_metadataKey, {
        'keyCreatedAt': DateTime.now().toUtc().toIso8601String(),
      });
      return publicKey;
    }
    return await _keystore.getPublicKey(_identityAlias) ??
        await _keystore.generateKeyPair(_identityAlias);
  }

  Future<String> getLocalPublicKey() async {
    return await _keystore.getPublicKey(_identityAlias) ?? '';
  }

  Future<String> signData(String data) async {
    return await _keystore.signData(_identityAlias, data);
  }

  Future<bool> verifySignature(String publicKey, String data, String signature) async {
    return await _keystore.verifySignature(publicKey, data, signature);
  }

  Future<DateTime> _localKeyCreatedAt() async {
    final metadata = LocalDatabase.toStringDynamicMap(
      LocalDatabase.auth().get(_metadataKey),
    );
    return DateTime.tryParse(metadata['keyCreatedAt'] as String? ?? '')?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  Future<String> getLocalDeviceId() => _localDeviceId();

  Future<String> _localDeviceId() async {
    final box = LocalDatabase.auth();
    final existing = box.get(_deviceIdKey) as String?;
    if (existing != null && existing.isNotEmpty) return existing;
    final id = LocalDatabase.newId('ble_device');
    await box.put(_deviceIdKey, id);
    return id;
  }

  Future<String> _localHardwareId() async {
    try {
      if (Platform.isAndroid) {
        final android = await DeviceInfoPlugin().androidInfo;
        return android.id;
      } else if (Platform.isIOS) {
        final ios = await DeviceInfoPlugin().iosInfo;
        return ios.identifierForVendor ?? '';
      }
    } catch (_) {}
    return '';
  }

  Future<String> getLocalDeviceName() => _localDeviceName();

  Future<String> _localDeviceName() async {
    try {
      final user = (await _getLocalAuthUser());
      final name = user['name'] as String?;
      if (name != null && name.trim().isNotEmpty) return name.trim();
    } catch (_) {}
    try {
      if (Platform.isAndroid) {
        final android = await DeviceInfoPlugin().androidInfo;
        return '${android.manufacturer} ${android.model}';
      } else if (Platform.isIOS) {
        final ios = await DeviceInfoPlugin().iosInfo;
        return ios.name;
      }
    } catch (_) {}
    return 'Dispositivo CatechHub';
  }

  Future<Map<String, dynamic>> _getLocalAuthUser() async {
    final box = LocalDatabase.auth();
    return {
      'name': box.get('local_user_name', defaultValue: ''),
      'firstName': box.get('first_name', defaultValue: ''),
      'lastName': box.get('last_name', defaultValue: ''),
    };
  }

  static String publicKeyFingerprint(String publicKey) {
    final digest = sha256.convert(utf8.encode(publicKey)).bytes;
    return digest
        .take(6)
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join(':')
        .toUpperCase();
  }

  Future<void> addSyncLog(BleSyncLog log) async {
    await LocalDatabase.syncLogs().put(log.id, log.toMap());
  }
}

class BleSyncLog {
  final String id;
  final String deviceId;
  final String deviceName;
  final PairingDeviceRole role;
  final DateTime createdAt;
  final String action;
  final String details;

  const BleSyncLog({
    required this.id,
    required this.deviceId,
    required this.deviceName,
    required this.role,
    required this.createdAt,
    required this.action,
    required this.details,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'deviceId': deviceId,
    'deviceName': deviceName,
    'role': role.storageValue,
    'createdAt': createdAt.toIso8601String(),
    'action': action,
    'details': details,
  };

  factory BleSyncLog.fromMap(Map<String, dynamic> map, String id) {
    return BleSyncLog(
      id: id,
      deviceId: map['deviceId'] as String? ?? '',
      deviceName: map['deviceName'] as String? ?? 'Locale',
      role: PairedBleDevice._roleFromStorage(map['role'] as String?),
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      action: map['action'] as String? ?? 'unknown',
      details: map['details'] as String? ?? '',
    );
  }
}
