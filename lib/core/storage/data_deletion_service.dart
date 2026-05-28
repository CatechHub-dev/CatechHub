import '../../shared/models/attachment_model.dart';
import '../../shared/models/attachment_parent_type.dart';
import 'encrypted_file_storage.dart';
import 'local_database.dart';

enum DataDeletionCategory {
  anagrafica,
  presenze,
  giornate,
  allegati,
}

class DataDeletionCounts {
  const DataDeletionCounts({
    required this.students,
    required this.attendance,
    required this.planning,
    required this.attachments,
  });

  final int students;
  final int attendance;
  final int planning;
  final int attachments;

  int get total => students + attendance + planning + attachments;
}

class DataDeletionService {
  DataDeletionCounts getCounts() {
    return DataDeletionCounts(
      students: LocalDatabase.students().length,
      attendance: LocalDatabase.attendance().length,
      planning: LocalDatabase.planning().length,
      attachments: LocalDatabase.attachments().length,
    );
  }

  Future<void> deleteSelected(Set<DataDeletionCategory> categories) async {
    if (categories.isEmpty) {
      throw Exception('Seleziona almeno una voce da cancellare');
    }

    if (categories.contains(DataDeletionCategory.allegati)) {
      await _deleteAllAttachments();
    } else {
      if (categories.contains(DataDeletionCategory.anagrafica)) {
        await _deleteAttachmentsForParentType(AttachmentParentType.student);
      }
      if (categories.contains(DataDeletionCategory.giornate)) {
        await _deleteAttachmentsForParentType(AttachmentParentType.meeting);
      }
    }

    if (categories.contains(DataDeletionCategory.presenze)) {
      await LocalDatabase.attendance().clear();
    }

    if (categories.contains(DataDeletionCategory.giornate)) {
      await LocalDatabase.planning().clear();
    }

    if (categories.contains(DataDeletionCategory.anagrafica)) {
      await _deleteAnagrafica();
    }
  }

  Future<void> _deleteAnagrafica() async {
    await LocalDatabase.students().clear();

    final classesBox = LocalDatabase.classes();
    for (final classKey in classesBox.keys) {
      final data = LocalDatabase.toStringDynamicMap(classesBox.get(classKey));
      data['studentIds'] = <String>[];
      await classesBox.put(classKey, data);
    }

    await LocalDatabase.documentDeliveries().clear();
  }

  Future<void> _deleteAllAttachments() async {
    final box = LocalDatabase.attachments();
    for (final key in box.keys.toList()) {
      await EncryptedFileStorage.delete(key.toString());
    }
    await box.clear();
    await EncryptedFileStorage.deleteAll();
  }

  Future<void> _deleteAttachmentsForParentType(String parentType) async {
    final box = LocalDatabase.attachments();
    final toRemove = <String>[];

    for (final key in box.keys) {
      final id = key.toString();
      final data = LocalDatabase.toStringDynamicMap(box.get(key));
      final attachment = Attachment.fromMap(id, data);
      if (attachment.parentType == parentType) {
        toRemove.add(id);
      }
    }

    for (final id in toRemove) {
      await EncryptedFileStorage.delete(id);
      await box.delete(id);
    }
  }
}
