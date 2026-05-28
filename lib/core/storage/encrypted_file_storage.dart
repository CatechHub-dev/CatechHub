import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'local_database.dart';

/// Salva file solo nella directory privata dell'app, cifrati con la stessa chiave Hive.
class EncryptedFileStorage {
  /// Dopo l'ottimizzazione gli allegati restano sotto questa soglia.
  static const maxFileBytes = 6 * 1024 * 1024;
  static const _vaultFolder = 'secure_vault';

  static Future<Directory> _vaultDirectory() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/$_vaultFolder');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<File> _fileFor(String storageId) async {
    final dir = await _vaultDirectory();
    return File('${dir.path}/$storageId.vault');
  }

  static Future<void> write(String storageId, Uint8List plainBytes) async {
    if (plainBytes.length > maxFileBytes) {
      throw Exception(
        'File troppo grande (max ${maxFileBytes ~/ (1024 * 1024)} MB)',
      );
    }
    final encrypted = LocalDatabase.encryptBytes(plainBytes);
    final file = await _fileFor(storageId);
    await file.writeAsBytes(encrypted, flush: true);
  }

  static Future<Uint8List> read(String storageId) async {
    final file = await _fileFor(storageId);
    if (!await file.exists()) {
      throw Exception('File allegato non trovato');
    }
    final encrypted = await file.readAsBytes();
    return LocalDatabase.decryptBytes(encrypted);
  }

  static Future<bool> exists(String storageId) async {
    return (await _fileFor(storageId)).exists();
  }

  static Future<void> delete(String storageId) async {
    final file = await _fileFor(storageId);
    if (await file.exists()) {
      await file.delete();
    }
  }

  static Future<void> deleteAll() async {
    final dir = await _vaultDirectory();
    if (!await dir.exists()) return;

    await for (final entity in dir.list()) {
      if (entity is File) {
        await entity.delete();
      }
    }
  }
}
