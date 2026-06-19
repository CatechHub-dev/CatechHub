import 'dart:convert';
import 'dart:typed_data';

import 'package:hive/hive.dart';

import '../storage/encrypted_file_storage.dart';
import '../storage/local_database.dart';
import '../../shared/models/student_model.dart';
import '../../shared/models/class_model.dart';
import '../../shared/models/planning_meeting.dart';
import '../../shared/models/attachment_model.dart';
import '../../shared/models/contact_note_model.dart';
import 'encryption_service.dart';

class DataExportService {
  // Esporta tutti i dati dal database
  static Future<Map<String, dynamic>> exportAllData() async {
    final Map<String, dynamic> allData = {
      'anagrafica': _exportAnagrafica(),
      'allegati_studenti': await _exportAllegatiPerTipo('student'),
      'agenda': _exportAgenda(),
      'programmazione': _exportProgrammazione(),
      'allegati_giornate': await _exportAllegatiPerTipo('meeting'),
      'documenti': _exportDocumenti(),
      'note_contatto': _exportNoteContatto(),
    };

    return allData;
  }

  // Esporta dati selettivi basati su opzioni
  static Future<Map<String, dynamic>> exportSelectiveData(
    bool includeAnagrafica,
    bool includeAgenda,
    bool includeProgrammazione,
    bool includeDocumenti,
    bool includeContactNotes,
    bool includeAnagraficaAttachments,
    bool includeAgendaAttachments,
  ) async {
    final Map<String, dynamic> selectiveData = {};

    if (includeAnagrafica) {
      selectiveData['anagrafica'] = _exportAnagrafica();
      if (includeAnagraficaAttachments) {
        selectiveData['allegati_studenti'] = await _exportAllegatiPerTipo(
          'student',
        );
      }
    }

    if (includeAgenda) {
      selectiveData['agenda'] = _exportAgenda();
    }

    if (includeProgrammazione) {
      selectiveData['programmazione'] = _exportProgrammazione();
      if (includeAgendaAttachments) {
        selectiveData['allegati_giornate'] = await _exportAllegatiPerTipo(
          'meeting',
        );
      }
    }

    if (includeDocumenti) {
      selectiveData['documenti'] = _exportDocumenti();
    }

    if (includeContactNotes) {
      selectiveData['note_contatto'] = _exportNoteContatto();
    }

    return selectiveData;
  }

  // Esporta anagrafica (studenti e classi)
  static Map<String, dynamic> _exportAnagrafica() {
    final students = LocalDatabase.values(
      LocalDatabase.students(),
      (id, data) => Student.fromMap(id, data),
    );

    final classes = LocalDatabase.values(
      LocalDatabase.classes(),
      (id, data) => SchoolClass.fromMap(id, data),
    );

    return {
      'students': students.map((s) => s.toMap()..['id'] = s.id).toList(),
      'classes': classes.map((c) => c.toMap()..['id'] = c.id).toList(),
    };
  }

  // Esporta agenda (presenze)
  static Map<String, dynamic> _exportAgenda() {
    final attendance = LocalDatabase.values(
      LocalDatabase.attendance(),
      (id, data) => {'id': id, ...data},
    );

    return {'attendance': attendance};
  }

  // Esporta programmazione (planning)
  static Map<String, dynamic> _exportProgrammazione() {
    final planning = LocalDatabase.values(
      LocalDatabase.planning(),
      (id, data) => PlanningMeeting.fromMap(id, data),
    );

    return {'planning': planning.map((p) => p.toMap()..['id'] = p.id).toList()};
  }

  // Esporta documenti
  static Map<String, dynamic> _exportDocumenti() {
    final documents = LocalDatabase.values(
      LocalDatabase.documents(),
      (id, data) => {'id': id, ...data},
    );

    final deliveries = LocalDatabase.values(
      LocalDatabase.documentDeliveries(),
      (id, data) => {'id': id, ...data},
    );

    return {'documents': documents, 'deliveries': deliveries};
  }

  // Esporta allegati per tipo specifico (student o meeting)
  static Future<Map<String, dynamic>> _exportAllegatiPerTipo(
    String parentType,
  ) async {
    final allAttachments = LocalDatabase.values(
      LocalDatabase.attachments(),
      (id, data) => Attachment.fromMap(id, data),
    );

    // Filtra per tipo
    final filteredAttachments = allAttachments
        .where((a) => a.parentType == parentType)
        .toList();

    // Includi i dati binari (base64) di ogni allegato
    final List<Map<String, dynamic>> attachmentsWithData = [];
    for (final a in filteredAttachments) {
      final map = a.toMap()..['id'] = a.id;
      try {
        final fileBytes = await EncryptedFileStorage.read(a.id);
        map['fileData'] = base64Encode(fileBytes);
      } catch (_) {
        // File non trovato su disco: esporta solo i metadati
      }
      attachmentsWithData.add(map);
    }

    return {'attachments': attachmentsWithData, 'parentType': parentType};
  }

  // Importa dati ricevuti facendo merge con quelli esistenti
  static Future<void> importData(Map<String, dynamic> receivedData) async {
    // Importa anagrafica
    if (receivedData.containsKey('anagrafica')) {
      await _importAnagrafica(receivedData['anagrafica']);
    }

    // Importa allegati dei ragazzi
    if (receivedData.containsKey('allegati_studenti')) {
      await _importAllegati(receivedData['allegati_studenti'], 'student');
    }

    // Importa agenda
    if (receivedData.containsKey('agenda')) {
      await _importAgenda(receivedData['agenda']);
    }

    // Importa programmazione
    if (receivedData.containsKey('programmazione')) {
      await _importProgrammazione(receivedData['programmazione']);
    }

    // Importa allegati delle giornate
    if (receivedData.containsKey('allegati_giornate')) {
      await _importAllegati(receivedData['allegati_giornate'], 'meeting');
    }

    // Importa documenti
    if (receivedData.containsKey('documenti')) {
      await _importDocumenti(receivedData['documenti']);
    }

    // Importa allegati generici (per compatibilità con vecchi export)
    if (receivedData.containsKey('allegati')) {
      await _importAllegatiGenerici(receivedData['allegati']);
    }

    // Importa note di contatto
    if (receivedData.containsKey('note_contatto')) {
      await _importNoteContatto(receivedData['note_contatto']);
    }
  }

  static Map<String, dynamic> _mergeMaps(
    Map<String, dynamic> localData,
    Map<String, dynamic> incomingData,
  ) {
    final merged = Map<String, dynamic>.from(localData);

    for (final entry in incomingData.entries) {
      final key = entry.key;
      if (key == 'id') continue;

      final value = entry.value;
      if (value == null) continue;

      if (merged[key] != value) {
        merged[key] = value;
      }
    }

    return merged;
  }

  static Future<void> _mergeBoxRecords(
    Box<Map> box,
    List<dynamic>? incomingItems,
  ) async {
    if (incomingItems == null) return;

    for (final item in incomingItems) {
      final record = Map<String, dynamic>.from(item as Map);
      final id = record.remove('id') as String? ?? LocalDatabase.newId();
      final existing = LocalDatabase.toStringDynamicMap(box.get(id));

      if (existing.isEmpty) {
        await box.put(id, record);
        continue;
      }

      final merged = _mergeMaps(existing, record);
      if (merged.toString() != existing.toString()) {
        await box.put(id, merged);
      }
    }
  }

  // Importa anagrafica
  static Future<void> _importAnagrafica(
    Map<String, dynamic> anagraficaData,
  ) async {
    await _mergeBoxRecords(
      LocalDatabase.students(),
      anagraficaData['students'] as List<dynamic>?,
    );

    await _mergeBoxRecords(
      LocalDatabase.classes(),
      anagraficaData['classes'] as List<dynamic>?,
    );
  }

  // Importa agenda
  static Future<void> _importAgenda(Map<String, dynamic> agendaData) async {
    await _mergeBoxRecords(
      LocalDatabase.attendance(),
      agendaData['attendance'] as List<dynamic>?,
    );
  }

  // Importa programmazione
  static Future<void> _importProgrammazione(
    Map<String, dynamic> programmazioneData,
  ) async {
    await _mergeBoxRecords(
      LocalDatabase.planning(),
      programmazioneData['planning'] as List<dynamic>?,
    );
  }

  // Importa documenti
  static Future<void> _importDocumenti(
    Map<String, dynamic> documentiData,
  ) async {
    await _mergeBoxRecords(
      LocalDatabase.documents(),
      documentiData['documents'] as List<dynamic>?,
    );

    await _mergeBoxRecords(
      LocalDatabase.documentDeliveries(),
      documentiData['deliveries'] as List<dynamic>?,
    );
  }

  // Importa allegati per tipo specifico
  static Future<void> _importAllegati(
    Map<String, dynamic> allegatiData,
    String parentType,
  ) async {
    final attachmentsBox = LocalDatabase.attachments();
    final incomingAttachments = allegatiData['attachments'] as List<dynamic>?;

    if (incomingAttachments == null) return;

    for (final attachmentData in incomingAttachments) {
      final attachmentMap = Map<String, dynamic>.from(attachmentData as Map);
      final id =
          attachmentMap.remove('id') as String? ??
          LocalDatabase.newId('attachment');
      final localRecord = LocalDatabase.toStringDynamicMap(
        attachmentsBox.get(id),
      );
      final localAttachment = localRecord.isEmpty
          ? null
          : Attachment.fromMap(id, localRecord);

      final fileDataB64 = attachmentMap.remove('fileData') as String?;
      final incomingCreatedAt =
          DateTime.tryParse(attachmentMap['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);

      if (localAttachment != null) {
        if (fileDataB64 != null && fileDataB64.isNotEmpty) {
          if (localAttachment.fileHash == attachmentMap['fileHash']) {
            // Stesso file, aggiorna solo metadati se necessario.
            final merged = _mergeMaps(localRecord, attachmentMap);
            if (merged.toString() != localRecord.toString()) {
              await attachmentsBox.put(id, merged);
            }
            continue;
          }

          if (incomingCreatedAt.isAfter(localAttachment.createdAt)) {
            final fileBytes = Uint8List.fromList(base64Decode(fileDataB64));
            await EncryptedFileStorage.write(id, fileBytes);
            final merged = _mergeMaps(localRecord, attachmentMap);
            await attachmentsBox.put(id, merged);
            continue;
          }

          // Se il file locale è più recente, conserva il file locale e aggiorna solo i metadati non file.
          final merged = _mergeMaps(localRecord, attachmentMap);
          if (merged.toString() != localRecord.toString()) {
            await attachmentsBox.put(id, merged);
          }
          continue;
        }

        // Se non ci sono dati binari in arrivo, mantieni il file locale e aggiorna solo metadati.
        final merged = _mergeMaps(localRecord, attachmentMap);
        if (merged.toString() != localRecord.toString()) {
          await attachmentsBox.put(id, merged);
        }
        continue;
      }

      // Nuovo allegato in arrivo
      if (fileDataB64 != null && fileDataB64.isNotEmpty) {
        final fileBytes = Uint8List.fromList(base64Decode(fileDataB64));
        await EncryptedFileStorage.write(id, fileBytes);
      }
      await attachmentsBox.put(id, attachmentMap);
    }
  }

  // Importa allegati generici (per compatibilità con vecchi export)
  static Future<void> _importAllegatiGenerici(
    Map<String, dynamic> allegatiData,
  ) async {
    final attachmentsBox = LocalDatabase.attachments();
    final incomingAttachments = allegatiData['attachments'] as List<dynamic>?;

    if (incomingAttachments == null) return;

    for (final attachmentData in incomingAttachments) {
      final attachmentMap = Map<String, dynamic>.from(attachmentData as Map);
      final id =
          attachmentMap.remove('id') as String? ??
          LocalDatabase.newId('attachment');
      final localRecord = LocalDatabase.toStringDynamicMap(
        attachmentsBox.get(id),
      );
      final localAttachment = localRecord.isEmpty
          ? null
          : Attachment.fromMap(id, localRecord);

      final fileDataB64 = attachmentMap.remove('fileData') as String?;
      final incomingCreatedAt =
          DateTime.tryParse(attachmentMap['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);

      if (localAttachment != null) {
        if (fileDataB64 != null && fileDataB64.isNotEmpty) {
          if (localAttachment.fileHash == attachmentMap['fileHash']) {
            final merged = _mergeMaps(localRecord, attachmentMap);
            if (merged.toString() != localRecord.toString()) {
              await attachmentsBox.put(id, merged);
            }
            continue;
          }

          if (incomingCreatedAt.isAfter(localAttachment.createdAt)) {
            final fileBytes = Uint8List.fromList(base64Decode(fileDataB64));
            await EncryptedFileStorage.write(id, fileBytes);
            final merged = _mergeMaps(localRecord, attachmentMap);
            await attachmentsBox.put(id, merged);
            continue;
          }

          final merged = _mergeMaps(localRecord, attachmentMap);
          if (merged.toString() != localRecord.toString()) {
            await attachmentsBox.put(id, merged);
          }
          continue;
        }

        final merged = _mergeMaps(localRecord, attachmentMap);
        if (merged.toString() != localRecord.toString()) {
          await attachmentsBox.put(id, merged);
        }
        continue;
      }

      if (fileDataB64 != null && fileDataB64.isNotEmpty) {
        final fileBytes = Uint8List.fromList(base64Decode(fileDataB64));
        await EncryptedFileStorage.write(id, fileBytes);
      }
      await attachmentsBox.put(id, attachmentMap);
    }
  }

  // Esporta note di contatto
  static Map<String, dynamic> _exportNoteContatto() {
    final notes = LocalDatabase.values(
      LocalDatabase.contactNotes(),
      (id, data) => ContactNote.fromMap(id, data),
    );

    return {'notes': notes.map((n) => n.toMap()..['id'] = n.id).toList()};
  }

  // Importa note di contatto
  static Future<void> _importNoteContatto(Map<String, dynamic> noteData) async {
    await _mergeBoxRecords(
      LocalDatabase.contactNotes(),
      noteData['notes'] as List<dynamic>?,
    );
  }

  // Verifica integrità dei dati ricevuti
  static bool verifyDataIntegrity(
    Map<String, dynamic> receivedData, {
    bool requireFullPackage = true,
  }) {
    if (requireFullPackage) {
      final requiredFields = [
        'anagrafica',
        'agenda',
        'programmazione',
        'documenti',
      ];
      for (final field in requiredFields) {
        if (!receivedData.containsKey(field)) {
          return false;
        }
      }
      return true;
    }

    final supportedFields = {
      'anagrafica',
      'agenda',
      'programmazione',
      'documenti',
      'allegati_studenti',
      'allegati_giornate',
      'note_contatto',
      'allegati',
    };

    return receivedData.keys.any(supportedFields.contains);
  }

  // Esporta tutti i dati cifrati con password
  static Future<String> exportEncryptedData(String password) async {
    final allData = await exportAllData();
    return EncryptionService.encryptData(allData, password);
  }

  // Importa dati cifrati con verifica password
  static Future<void> importEncryptedData(
    String encryptedData,
    String password,
  ) async {
    final decryptedData = EncryptionService.decryptData(
      encryptedData,
      password,
    );

    // Verifica integrità dati
    if (!verifyDataIntegrity(decryptedData)) {
      throw Exception('Integrità dei dati non valida');
    }

    // Importa i dati
    await importData(decryptedData);
  }

  // Verifica la password per dati cifrati
  static bool verifyEncryptedPassword(String encryptedData, String password) {
    return EncryptionService.verifyPassword(encryptedData, password);
  }
}
