import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

class LocalDatabase {
  static const authBox = 'registroBox';
  static const classesBox = 'classes_box';
  static const studentsBox = 'students_box';
  static const planningBox = 'planning_box';
  static const attendanceBox = 'attendance_box';
  static const documentsBox = 'documents_box';
  static const documentDeliveriesBox = 'document_deliveries_box';

  static const _secureStorage = FlutterSecureStorage();
  static const _encryptionKeyName = 'secure_database_key';

  static Future<void> init() async {
    await Hive.initFlutter();

    var encryptionKeyString = await _secureStorage.read(key: _encryptionKeyName);
    if (encryptionKeyString == null) {
      final key = Hive.generateSecureKey();
      encryptionKeyString = base64UrlEncode(key);
      await _secureStorage.write(
        key: _encryptionKeyName,
        value: encryptionKeyString,
      );
    }

    final cipher = HiveAesCipher(base64Url.decode(encryptionKeyString));

    await Future.wait([
      Hive.openBox(authBox, encryptionCipher: cipher),
      Hive.openBox<Map>(classesBox, encryptionCipher: cipher),
      Hive.openBox<Map>(studentsBox, encryptionCipher: cipher),
      Hive.openBox<Map>(planningBox, encryptionCipher: cipher),
      Hive.openBox<Map>(attendanceBox, encryptionCipher: cipher),
      Hive.openBox<Map>(documentsBox, encryptionCipher: cipher),
      Hive.openBox<Map>(documentDeliveriesBox, encryptionCipher: cipher),
    ]);
  }

  static Box auth() => Hive.box(authBox);
  static Box<Map> classes() => Hive.box<Map>(classesBox);
  static Box<Map> students() => Hive.box<Map>(studentsBox);
  static Box<Map> planning() => Hive.box<Map>(planningBox);
  static Box<Map> attendance() => Hive.box<Map>(attendanceBox);
  static Box<Map> documents() => Hive.box<Map>(documentsBox);
  static Box<Map> documentDeliveries() => Hive.box<Map>(documentDeliveriesBox);

  static String newId([String prefix = 'local']) {
    return '${prefix}_${DateTime.now().microsecondsSinceEpoch}';
  }

  static Stream<List<T>> watchList<T>(
    Box<Map> box,
    T Function(String id, Map<String, dynamic> data) mapper,
  ) async* {
    yield _boxValues(box, mapper);
    yield* box.watch().map((_) => _boxValues(box, mapper));
  }

  static List<T> values<T>(
    Box<Map> box,
    T Function(String id, Map<String, dynamic> data) mapper,
  ) {
    return _boxValues(box, mapper);
  }

  static List<T> _boxValues<T>(
    Box<Map> box,
    T Function(String id, Map<String, dynamic> data) mapper,
  ) {
    return box.keys.map((key) {
      final id = key.toString();
      final raw = box.get(key);
      return mapper(id, toStringDynamicMap(raw));
    }).toList();
  }

  static Map<String, dynamic> toStringDynamicMap(Object? value) {
    if (value == null) return {};
    return Map<String, dynamic>.from(value as Map);
  }
}
