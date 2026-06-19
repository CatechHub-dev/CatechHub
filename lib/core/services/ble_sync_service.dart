import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:pointycastle/export.dart' as pc;

import '../storage/local_database.dart';
import 'ble_discovery_service.dart';
import 'ble_pairing_service.dart';
import 'encryption_service.dart';
import 'keystore_service.dart';

SyncEncryptResult _encryptPayloadIsolate(SyncEncryptInput input) {
  try {
    final cipher = pc.GCMBlockCipher(pc.AESEngine())
      ..init(true, pc.AEADParameters(pc.KeyParameter(input.key), 128, input.nonce, Uint8List(0)));
    final encrypted = cipher.process(Uint8List.fromList(utf8.encode(input.plaintext)));
    return SyncEncryptResult(encrypted: encrypted, error: null);
  } catch (e) {
    return SyncEncryptResult(encrypted: null, error: '$e');
  }
}

SyncDecryptResult _decryptPayloadIsolate(SyncDecryptInput input) {
  try {
    final cipher = pc.GCMBlockCipher(pc.AESEngine())
      ..init(false, pc.AEADParameters(pc.KeyParameter(input.key), 128, input.nonce, Uint8List(0)));
    final decrypted = cipher.process(input.encrypted);
    return SyncDecryptResult(decrypted: decrypted, error: null);
  } catch (e) {
    return SyncDecryptResult(decrypted: null, error: '$e');
  }
}

SyncSummaryResult _buildSummaryIsolate(SyncSummaryInput input) {
  try {
    final summary = <String, Map<String, String>>{};
    for (final category in input.categories.entries) {
      final catSummary = <String, String>{};
      final data = category.value;
      for (final entry in data.entries) {
        if (entry.value is Map) {
          final updatedAt = (entry.value as Map)['updatedAt'] as String?;
          if (updatedAt != null) {
            catSummary[entry.key] = updatedAt;
          }
        }
      }
      summary[category.key] = catSummary;
    }
    return SyncSummaryResult(summary: summary);
  } catch (e) {
    return SyncSummaryResult(error: '$e');
  }
}

SyncDiffResult _computeDiffIsolate(SyncDiffInput input) {
  try {
    final toSend = <String, Map<String, dynamic>>{};
    for (final category in input.localData.entries) {
      final catKey = category.key;
      final localItems = category.value;
      final remoteSummary = input.remoteSummary[catKey] ?? {};
      final catToSend = <String, dynamic>{};
      for (final entry in localItems.entries) {
        final id = entry.key;
        if (entry.value is! Map) continue;
        final localUpdatedAt = (entry.value as Map)['updatedAt'] as String?;
        if (localUpdatedAt == null) continue;
        final remoteUpdatedAt = remoteSummary[id];
        if (remoteUpdatedAt == null || remoteUpdatedAt.compareTo(localUpdatedAt) < 0) {
          catToSend[id] = entry.value;
        }
      }
      if (catToSend.isNotEmpty) toSend[catKey] = catToSend;
    }
    return SyncDiffResult(toSend: toSend);
  } catch (e) {
    return SyncDiffResult(error: '$e');
  }
}

class SyncEncryptInput {
  final Uint8List key;
  final Uint8List nonce;
  final String plaintext;
  SyncEncryptInput({required this.key, required this.nonce, required this.plaintext});
}

class SyncEncryptResult {
  final Uint8List? encrypted;
  final String? error;
  SyncEncryptResult({this.encrypted, this.error});
}

class SyncDecryptInput {
  final Uint8List key;
  final Uint8List nonce;
  final Uint8List encrypted;
  SyncDecryptInput({required this.key, required this.nonce, required this.encrypted});
}

class SyncDecryptResult {
  final Uint8List? decrypted;
  final String? error;
  SyncDecryptResult({this.decrypted, this.error});
}

class SyncSummaryInput {
  final Map<String, Map<String, dynamic>> categories;
  SyncSummaryInput(this.categories);
}

class SyncSummaryResult {
  final Map<String, Map<String, String>>? summary;
  final String? error;
  SyncSummaryResult({this.summary, this.error});
}

class SyncDiffInput {
  final Map<String, Map<String, dynamic>> localData;
  final Map<String, Map<String, String>> remoteSummary;
  SyncDiffInput({required this.localData, required this.remoteSummary});
}

class SyncDiffResult {
  final Map<String, Map<String, dynamic>>? toSend;
  final String? error;
  SyncDiffResult({this.toSend, this.error});
}

/// Sent when the responder side needs the user to consent to sync.
class SyncConsentRequest {
  final String remoteDeviceId;
  final String remoteDeviceName;
  final Completer<bool> completer;
  SyncConsentRequest({
    required this.remoteDeviceId,
    required this.remoteDeviceName,
    required this.completer,
  });
}

class BleSyncService {
  static const _msgTimeout = Duration(seconds: 20);

  final BlePairingService _pairingService;
  final BleDiscoveryService _discoveryService;
  final KeystoreService _keystore;

  final StreamController<SyncConsentRequest> _consentController =
      StreamController<SyncConsentRequest>.broadcast();
  Stream<SyncConsentRequest> get onConsentRequired => _consentController.stream;

  bool _syncInProgress = false;

  BleSyncService({
    BlePairingService? pairingService,
    BleDiscoveryService? discoveryService,
    KeystoreService? keystore,
  })  : _pairingService = pairingService ?? BlePairingService(),
        _discoveryService = discoveryService ?? BleDiscoveryService(),
        _keystore = keystore ?? KeystoreService();

  /// Initiate sync as the initiator: connects to the remote device
  /// and drives the sync protocol.
  Future<bool> syncWithDevice(
    String deviceId,
    PairedBleDevice pairedDevice, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (_syncInProgress) return false;
    _syncInProgress = true;

    try {
      await _log(pairedDevice, 'sync_started', 'Connessione a ${pairedDevice.displayName}...');
      await _discoveryService.connectForSync(deviceId);

      final localPublicKey = await _pairingService.getLocalPublicKey();
      final localDeviceId = await _pairingService.getLocalDeviceId();
      final localDeviceName = await _pairingService.getLocalDeviceName();
      if (localPublicKey.isEmpty) throw Exception('Chiave pubblica locale non disponibile');

      await _sendMessage({
        'type': 'SYNC_REQ',
        'deviceId': localDeviceId,
        'publicKey': localPublicKey,
        'deviceName': localDeviceName,
      });

      final ack = await _waitForMessage('SYNC_ACK');
      if (ack['consented'] == false) {
        await _log(pairedDevice, 'sync_declined', 'Sync rifiutato dal dispositivo remoto');
        await _discoveryService.disconnect();
        return false;
      }

      if (pairedDevice.bleRemoteId != deviceId) {
        await _pairingService.updatePairedDevice(
          pairedDevice.id,
          pairedDevice.copyWith(bleRemoteId: deviceId),
        );
      }

      final localData = await _loadAllLocalData();
      final localSummary = await compute(_buildSummaryIsolate, SyncSummaryInput(localData));
      if (localSummary.error != null) {
        throw Exception('Errore creazione sommario: ${localSummary.error}');
      }

      await _sendMessage({'type': 'SUMMARY', 'data': localSummary.summary});
      final remoteSummaryMsg = await _waitForMessage('SUMMARY');
      final remoteSummary = Map<String, Map<String, String>>.from(
        (remoteSummaryMsg['data'] as Map).map(
          (k, v) => MapEntry(k as String, Map<String, String>.from(v as Map)),
        ),
      );

      final diffResult = await compute(
        _computeDiffIsolate,
        SyncDiffInput(localData: localData, remoteSummary: remoteSummary),
      );
      if (diffResult.error != null) {
        throw Exception('Errore calcolo diff: ${diffResult.error}');
      }

      final toSend = diffResult.toSend!;
      if (toSend.isNotEmpty) {
        final encrypted = await _encryptPackage(toSend, pairedDevice.publicKey);
        await _sendMessage({'type': 'DATA', 'package': encrypted});
      } else {
        await _sendMessage({'type': 'DATA', 'package': null});
      }

      final remoteDataMsg = await _waitForMessage('DATA');
      if (remoteDataMsg['package'] != null) {
        final remoteData = await _decryptPackage(remoteDataMsg['package'] as String);
        if (remoteData != null) {
          await _mergeRemoteData(remoteData);
        }
      }

      await _sendMessage({'type': 'DONE'});
      await _log(pairedDevice, 'sync_completed', 'Sincronizzazione completata');

      final updatedDevice = pairedDevice.copyWith(
        lastSyncAt: DateTime.now().toUtc(),
        bleRemoteId: deviceId,
      );
      await _pairingService.updatePairedDevice(pairedDevice.id, updatedDevice);

      await _discoveryService.disconnect();
      return true;
    } catch (e) {
      debugPrint('Sync error: $e');
      await _log(pairedDevice, 'sync_failed', 'Errore: $e');
      await _discoveryService.disconnect();
      return false;
    } finally {
      _syncInProgress = false;
    }
  }

  /// Handle an incoming sync message as responder.
  /// Called when the RFCOMM server receives a SYNC_REQ.
  /// Returns true if sync was completed successfully.
  Future<bool> handleIncomingSync(
    PairedBleDevice pairedDevice,
    Map<String, dynamic> syncReq,
  ) async {
    if (_syncInProgress) return false;
    _syncInProgress = true;

    try {
      final remoteDeviceId = syncReq['deviceId'] as String? ?? '';

      bool consented = true;
      if (pairedDevice.needsConsent) {
        final completer = Completer<bool>();
        _consentController.add(SyncConsentRequest(
          remoteDeviceId: remoteDeviceId,
          remoteDeviceName: pairedDevice.displayName,
          completer: completer,
        ));
        consented = await completer.future.timeout(
          const Duration(seconds: 30),
          onTimeout: () => false,
        );
      }

      if (!consented) {
        await _respondMessage({'type': 'SYNC_ACK', 'consented': false});
        await _log(pairedDevice, 'sync_declined', 'Sync rifiutato dall\'utente');
        return false;
      }

      await _respondMessage({'type': 'SYNC_ACK', 'consented': true});

      final summaryMsg = await _waitForMessage('SUMMARY');
      final remoteSummary = Map<String, Map<String, String>>.from(
        (summaryMsg['data'] as Map).map(
          (k, v) => MapEntry(k as String, Map<String, String>.from(v as Map)),
        ),
      );

      final localData = await _loadAllLocalData();
      final localSummary = await compute(_buildSummaryIsolate, SyncSummaryInput(localData));
      if (localSummary.error != null) {
        throw Exception('Errore creazione sommario: ${localSummary.error}');
      }

      await _respondMessage({'type': 'SUMMARY', 'data': localSummary.summary});

      final diffResult = await compute(
        _computeDiffIsolate,
        SyncDiffInput(localData: localData, remoteSummary: remoteSummary),
      );
      if (diffResult.error != null) {
        throw Exception('Errore calcolo diff: ${diffResult.error}');
      }

      final remoteDataMsg = await _waitForMessage('DATA');
      if (remoteDataMsg['package'] != null) {
        final remoteData = await _decryptPackage(remoteDataMsg['package'] as String);
        if (remoteData != null) {
          await _mergeRemoteData(remoteData);
        }
      }

      final toSend = diffResult.toSend!;
      if (toSend.isNotEmpty) {
        final encrypted = await _encryptPackage(toSend, pairedDevice.publicKey);
        await _respondMessage({'type': 'DATA', 'package': encrypted});
      } else {
        await _respondMessage({'type': 'DATA', 'package': null});
      }

      await _waitForMessage('DONE');

      await _log(pairedDevice, 'sync_completed', 'Sincronizzazione completata (responder)');
      final updatedDevice = pairedDevice.copyWith(lastSyncAt: DateTime.now().toUtc());
      await _pairingService.updatePairedDevice(pairedDevice.id, updatedDevice);
      return true;
    } catch (e) {
      debugPrint('Sync responder error: $e');
      await _log(pairedDevice, 'sync_failed', 'Errore responder: $e');
      return false;
    } finally {
      _syncInProgress = false;
    }
  }

  Future<void> _sendMessage(Map<String, dynamic> msg) async {
    await _discoveryService.sendData(jsonEncode(msg));
  }

  Future<void> _respondMessage(Map<String, dynamic> msg) async {
    await _discoveryService.respondToSyncRequest(jsonEncode(msg));
  }

  Future<Map<String, dynamic>> _waitForMessage(String expectedType) async {
    final data = await _discoveryService.onSyncDataReceived
        .firstWhere(
          (raw) {
            try {
              final msg = jsonDecode(raw) as Map<String, dynamic>;
              return msg['type'] == expectedType;
            } catch (_) {
              return false;
            }
          },
        )
        .timeout(_msgTimeout, onTimeout: () => throw Exception('Timeout attesa $expectedType'));
    return jsonDecode(data) as Map<String, dynamic>;
  }

  Future<String> _encryptPackage(Map<String, dynamic> data, String remotePublicKey) async {
    final ephemeralKey = EncryptionService.secureRandomBytes(32);
    final nonce = EncryptionService.secureRandomBytes(12);
    final plaintext = jsonEncode(data);

    final encryptResult = await compute(
      _encryptPayloadIsolate,
      SyncEncryptInput(key: ephemeralKey, nonce: nonce, plaintext: plaintext),
    );
    if (encryptResult.error != null) {
      throw Exception('Cifratura AES fallita: ${encryptResult.error}');
    }

    final keyBase64 = base64Encode(ephemeralKey);
    final encryptedKey = await _keystore.encryptWithPublicKey(remotePublicKey, keyBase64);

    final package = {
      'v': 2,
      'nonce': base64Encode(nonce),
      'encryptedKey': encryptedKey,
      'data': base64Encode(encryptResult.encrypted!),
      'ts': DateTime.now().toUtc().toIso8601String(),
    };

    return base64Encode(utf8.encode(jsonEncode(package)));
  }

  Future<Map<String, dynamic>?> _decryptPackage(String packaged) async {
    try {
      final packageStr = utf8.decode(base64Decode(packaged));
      final package = jsonDecode(packageStr) as Map<String, dynamic>;

      final encryptedKey = package['encryptedKey'] as String;
      final keyBase64 = await _keystore.decryptWithPrivateKey(
        BlePairingService.identityAlias,
        encryptedKey,
      );
      final ephemeralKey = base64Decode(keyBase64);

      final nonce = base64Decode(package['nonce'] as String);
      final encryptedData = base64Decode(package['data'] as String);

      final decryptResult = await compute(
        _decryptPayloadIsolate,
        SyncDecryptInput(key: ephemeralKey, nonce: nonce, encrypted: encryptedData),
      );
      if (decryptResult.error != null) {
        throw Exception('Decifratura AES fallita: ${decryptResult.error}');
      }

      final decryptedStr = utf8.decode(decryptResult.decrypted!);
      return jsonDecode(decryptedStr) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Errore decifratura pacchetto sync: $e');
      return null;
    }
  }

  Future<Map<String, Map<String, dynamic>>> _loadAllLocalData() async {
    final result = await compute(_loadLocalDataIsolate, LoadDataInput());
    if (result.error != null) {
      throw Exception('Errore caricamento dati: ${result.error}');
    }
    return result.data!;
  }

  Future<void> _mergeRemoteData(Map<String, dynamic> remoteData) async {
    final result = await compute(
      _mergeRemoteDataIsolate,
      MergeDataInput(remoteData: remoteData),
    );

    if (result.error != null) {
      throw Exception('Errore merge dati: ${result.error}');
    }

    final categoryMap = {
      'anagrafica': LocalDatabase.students(),
      'allegati_studenti': LocalDatabase.attachments(),
      'agenda': LocalDatabase.attendance(),
      'programmazione': LocalDatabase.planning(),
      'documenti': LocalDatabase.documents(),
      'note_contatto': LocalDatabase.contactNotes(),
    };

    for (final op in result.operations!) {
      final category = op['category'] as String;
      final id = op['id'] as String;
      final action = op['action'] as String;
      final data = op['data'] as Map<String, dynamic>;

      final box = categoryMap[category];
      if (box != null && action == 'put') {
        await box.put(id, data);
      }
    }
  }

  Future<void> _log(PairedBleDevice device, String action, String details) async {
    final log = BleSyncLog(
      id: LocalDatabase.newId('ble_sync'),
      deviceId: device.id,
      deviceName: device.displayName,
      role: device.role,
      createdAt: DateTime.now().toUtc(),
      action: action,
      details: details,
    );
    await LocalDatabase.syncLogs().put(log.id, log.toMap());
  }
}

LoadDataResult _loadLocalDataIsolate(LoadDataInput input) {
  try {
    final data = <String, Map<String, dynamic>>{};
    data['anagrafica'] = LocalDatabase.toStringDynamicMap(LocalDatabase.students().toMap());
    data['allegati_studenti'] = LocalDatabase.toStringDynamicMap(LocalDatabase.attachments().toMap());
    data['agenda'] = LocalDatabase.toStringDynamicMap(LocalDatabase.attendance().toMap());
    data['programmazione'] = LocalDatabase.toStringDynamicMap(LocalDatabase.planning().toMap());
    data['documenti'] = LocalDatabase.toStringDynamicMap(LocalDatabase.documents().toMap());
    data['note_contatto'] = LocalDatabase.toStringDynamicMap(LocalDatabase.contactNotes().toMap());
    return LoadDataResult(data: data);
  } catch (e) {
    return LoadDataResult(error: '$e');
  }
}

class LoadDataInput {
  LoadDataInput();
}

class LoadDataResult {
  final Map<String, Map<String, dynamic>>? data;
  final String? error;
  LoadDataResult({this.data, this.error});
}

MergeDataResult _mergeRemoteDataIsolate(MergeDataInput input) {
  try {
    final categoryMap = {
      'anagrafica': LocalDatabase.students(),
      'allegati_studenti': LocalDatabase.attachments(),
      'agenda': LocalDatabase.attendance(),
      'programmazione': LocalDatabase.planning(),
      'documenti': LocalDatabase.documents(),
      'note_contatto': LocalDatabase.contactNotes(),
    };

    final mergeOperations = <Map<String, dynamic>>[];

    for (final entry in input.remoteData.entries) {
      final box = categoryMap[entry.key];
      if (box != null && entry.value is Map) {
        for (final itemEntry in (entry.value as Map<String, dynamic>).entries) {
          final id = itemEntry.key;
          if (itemEntry.value is! Map) continue;
          final remoteItem = itemEntry.value as Map<String, dynamic>;
          final remoteTime = DateTime.tryParse(remoteItem['updatedAt'] as String? ?? '');

          final existing = box.get(id);
          if (existing == null) {
            mergeOperations.add({
              'category': entry.key, 'id': id, 'action': 'put', 'data': remoteItem,
            });
          } else {
            final existingTime = DateTime.tryParse(
              existing['updatedAt'] as String? ?? '',
            );
            if (remoteTime != null &&
                (existingTime == null || remoteTime.isAfter(existingTime))) {
              final merged = Map<String, dynamic>.from(existing);
              merged.addAll(remoteItem);
              mergeOperations.add({
                'category': entry.key, 'id': id, 'action': 'put', 'data': merged,
              });
            }
          }
        }
      }
    }

    return MergeDataResult(operations: mergeOperations);
  } catch (e) {
    return MergeDataResult(error: '$e');
  }
}

class MergeDataInput {
  final Map<String, dynamic> remoteData;
  MergeDataInput({required this.remoteData});
}

class MergeDataResult {
  final List<Map<String, dynamic>>? operations;
  final String? error;
  MergeDataResult({this.operations, this.error});
}
