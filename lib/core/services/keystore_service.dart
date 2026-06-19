import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';

class KeystoreService {
  static const MethodChannel _channel = MethodChannel('com.catechhub/keystore');
  
  static final KeystoreService _instance = KeystoreService._internal();
  factory KeystoreService() => _instance;
  KeystoreService._internal();

  Future<String> generateKeyPair(String alias) async {
    try {
      final result = await _channel.invokeMethod('generateKeyPair', {
        'alias': alias,
      });
      return result as String;
    } on PlatformException catch (e) {
      throw Exception('Errore nella generazione delle chiavi: ${e.message}');
    }
  }

  Future<String?> getPublicKey(String alias) async {
    try {
      final result = await _channel.invokeMethod('getPublicKey', {
        'alias': alias,
      });
      return result as String?;
    } on PlatformException catch (e) {
      throw Exception('Errore nel recupero della chiave pubblica: ${e.message}');
    }
  }

  Future<String> signData(String alias, String data) async {
    try {
      final result = await _channel.invokeMethod('signData', {
        'alias': alias,
        'data': data,
      });
      return result as String;
    } on PlatformException catch (e) {
      throw Exception('Errore nella firma dei dati: ${e.message}');
    }
  }

  Future<bool> verifySignature(String publicKey, String data, String signature) async {
    try {
      final result = await _channel.invokeMethod('verifySignature', {
        'publicKey': publicKey,
        'data': data,
        'signature': signature,
      });
      return result as bool;
    } on PlatformException catch (e) {
      throw Exception('Errore nella verifica della firma: ${e.message}');
    }
  }

  Future<String> encryptWithPublicKey(String publicKey, String data) async {
    try {
      final result = await _channel.invokeMethod('encryptWithPublicKey', {
        'publicKey': publicKey,
        'data': data,
      });
      return result as String;
    } on PlatformException catch (e) {
      throw Exception('Errore nella cifratura: ${e.message}');
    }
  }

  Future<String> decryptWithPrivateKey(String alias, String encryptedData) async {
    try {
      final result = await _channel.invokeMethod('decryptWithPrivateKey', {
        'alias': alias,
        'encryptedData': encryptedData,
      });
      return result as String;
    } on PlatformException catch (e) {
      throw Exception('Errore nella decifratura: ${e.message}');
    }
  }

  Future<bool> keyExists(String alias) async {
    try {
      final result = await _channel.invokeMethod('keyExists', {
        'alias': alias,
      });
      return result as bool;
    } on PlatformException catch (e) {
      throw Exception('Errore nel controllo della chiave: ${e.message}');
    }
  }

  Future<void> deleteKey(String alias) async {
    try {
      await _channel.invokeMethod('deleteKey', {
        'alias': alias,
      });
    } on PlatformException catch (e) {
      throw Exception('Errore nell\'eliminazione della chiave: ${e.message}');
    }
  }

  Future<List<String>> listKeys() async {
    try {
      final result = await _channel.invokeMethod('listKeys');
      return (result as List<dynamic>).cast<String>();
    } on PlatformException catch (e) {
      throw Exception('Errore nel recupero delle chiavi: ${e.message}');
    }
  }
}
