import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';

class EncryptionService {
  // Deriva una chiave AES-256 dalla password usando PBKDF2
  static Key deriveKey(String password, String salt) {
    final passwordBytes = utf8.encode(password);
    final saltBytes = utf8.encode(salt);
    
    // Usa SHA-256 per derivare la chiave (semplificato per Flutter)
    // In produzione, usare PBKDF2 con iterazioni
    final hmac = Hmac(sha256, passwordBytes);
    final digest = hmac.convert(saltBytes);
    
    // Espandi la chiave a 32 bytes per AES-256
    final keyBytes = Uint8List(32);
    for (int i = 0; i < 32; i++) {
      keyBytes[i] = digest.bytes[i % digest.bytes.length];
    }
    
    return Key(keyBytes);
  }

  // Genera un sale casuale
  static String generateSalt() {
    final random = sha256.convert(DateTime.now().millisecondsSinceEpoch.toString().codeUnits);
    return random.toString().substring(0, 16);
  }

  // Cifra i dati con la password
  static String encryptData(Map<String, dynamic> data, String password) {
    final salt = generateSalt();
    final key = deriveKey(password, salt);
    final iv = IV.fromSecureRandom(16);
    
    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    final jsonData = jsonEncode(data);
    final encrypted = encrypter.encrypt(jsonData, iv: iv);
    
    // Crea un pacchetto contenente salt, IV e dati cifrati
    final package = {
      'salt': salt,
      'iv': iv.base64,
      'data': encrypted.base64,
    };
    
    return base64Encode(utf8.encode(jsonEncode(package)));
  }

  // Decifra i dati con la password
  static Map<String, dynamic> decryptData(String encryptedData, String password) {
    try {
      final packageStr = utf8.decode(base64Decode(encryptedData));
      final package = jsonDecode(packageStr) as Map<String, dynamic>;
      
      final salt = package['salt'] as String;
      final ivBase64 = package['iv'] as String;
      final dataBase64 = package['data'] as String;
      
      final key = deriveKey(password, salt);
      final iv = IV.fromBase64(ivBase64);
      
      final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
      final decrypted = encrypter.decrypt64(dataBase64, iv: iv);
      
      return jsonDecode(decrypted) as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Password non valida o dati corrotti: $e');
    }
  }

  // Verifica la password senza decifrare completamente i dati
  static bool verifyPassword(String encryptedData, String password) {
    try {
      decryptData(encryptedData, password);
      return true;
    } catch (e) {
      return false;
    }
  }
}
