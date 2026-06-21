import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

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
  static const attachmentsBox = 'attachments_box';
  static const contactNotesBox = 'contact_notes_box';
  static const pairedDevicesBox = 'paired_devices_box';
  static const syncLogsBox = 'ble_sync_logs_box';
  static const catechesiBox = 'catechesi_box';
  static const meetingCatechesiBox = 'meeting_catechesi_box';
  static const studentDailyNotesBox = 'student_daily_notes_box';

  static const _secureStorage = FlutterSecureStorage();
  static const _encryptionKeyName = 'secure_database_key';

  static late final HiveAesCipher _cipher;
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    await Hive.initFlutter();

    var encryptionKeyString = await _secureStorage.read(
      key: _encryptionKeyName,
    );
    if (encryptionKeyString == null) {
      final key = Hive.generateSecureKey();
      encryptionKeyString = base64UrlEncode(key);
      await _secureStorage.write(
        key: _encryptionKeyName,
        value: encryptionKeyString,
      );
    }

    _cipher = HiveAesCipher(base64Url.decode(encryptionKeyString));

    await Future.wait([
      Hive.openBox(authBox, encryptionCipher: _cipher),
      Hive.openBox<Map>(classesBox, encryptionCipher: _cipher),
      Hive.openBox<Map>(studentsBox, encryptionCipher: _cipher),
      Hive.openBox<Map>(planningBox, encryptionCipher: _cipher),
      Hive.openBox<Map>(attendanceBox, encryptionCipher: _cipher),
      Hive.openBox<Map>(documentsBox, encryptionCipher: _cipher),
      Hive.openBox<Map>(documentDeliveriesBox, encryptionCipher: _cipher),
      Hive.openBox<Map>(attachmentsBox, encryptionCipher: _cipher),
      Hive.openBox<Map>(contactNotesBox, encryptionCipher: _cipher),
      Hive.openBox<Map>(pairedDevicesBox, encryptionCipher: _cipher),
      Hive.openBox<Map>(syncLogsBox, encryptionCipher: _cipher),
      Hive.openBox<Map>(catechesiBox, encryptionCipher: _cipher),
      Hive.openBox(meetingCatechesiBox, encryptionCipher: _cipher),
      Hive.openBox<Map>(studentDailyNotesBox, encryptionCipher: _cipher),
    ]);

    // La sessione non va persistita: rimuove eventuali flag legacy:
    await Hive.box(authBox).delete('isLoggedIn');

    _initialized = true;
  }

  static Box auth() => Hive.box(authBox);
  static Box<Map> classes() => Hive.box<Map>(classesBox);
  static Box<Map> students() => Hive.box<Map>(studentsBox);
  static Box<Map> planning() => Hive.box<Map>(planningBox);
  static Box<Map> attendance() => Hive.box<Map>(attendanceBox);
  static Box<Map> documents() => Hive.box<Map>(documentsBox);
  static Box<Map> documentDeliveries() => Hive.box<Map>(documentDeliveriesBox);
  static Box<Map> attachments() => Hive.box<Map>(attachmentsBox);
  static Box<Map> contactNotes() => Hive.box<Map>(contactNotesBox);
  static Box<Map> pairedDevices() => Hive.box<Map>(pairedDevicesBox);
  static Box<Map> syncLogs() => Hive.box<Map>(syncLogsBox);
  static Box<Map> catechesi() => Hive.box<Map>(catechesiBox);
  static Box meetingCatechesi() => Hive.box(meetingCatechesiBox);
  static Box<Map> studentDailyNotes() => Hive.box<Map>(studentDailyNotesBox);

  static Uint8List encryptBytes(Uint8List plain) {
    final out = Uint8List(_cipher.maxEncryptedSize(plain));
    final len = _cipher.encrypt(plain, 0, plain.length, out, 0);
    return Uint8List.sublistView(out, 0, len);
  }

  static Uint8List decryptBytes(Uint8List encrypted) {
    final out = Uint8List(encrypted.length);
    final len = _cipher.decrypt(encrypted, 0, encrypted.length, out, 0);
    return Uint8List.sublistView(out, 0, len);
  }

  static String newId([String prefix = 'local']) {
    return '${prefix}_${DateTime.now().microsecondsSinceEpoch}';
  }

  static Stream<List<T>> watchList<T>(
    Box<Map> box,
    T Function(String id, Map<String, dynamic> data) mapper,
  ) async* {
    yield _boxValues(box, mapper);
    // OTTIMIZZAZIONE: Usiamo un piccolo delay (throttling) per evitare di ricalcolare la lista
    // troppe volte al secondo se ci sono molti eventi (es. log BLE)
    var lastUpdate = DateTime.now();
    await for (final _ in box.watch()) {
      if (DateTime.now().difference(lastUpdate) > const Duration(milliseconds: 500)) {
        yield _boxValues(box, mapper);
        lastUpdate = DateTime.now();
      }
    }
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
