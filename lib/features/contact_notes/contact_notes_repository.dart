import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/local_database.dart';
import '../../shared/models/contact_note_model.dart';

final contactNotesRepoProvider = Provider((ref) => ContactNotesRepository());

class ContactNotesRepository {
  final _box = LocalDatabase.contactNotes();

  Stream<List<ContactNote>> getNotesForStudent(String studentId) {
    return LocalDatabase.watchList(
      _box,
      (id, data) => ContactNote.fromMap(id, data),
    ).map((notes) => notes
        .where((n) => n.studentId == studentId)
        .toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime)));
  }

  List<ContactNote> getNotesForStudentSync(String studentId) {
    return LocalDatabase.values(
      _box,
      (id, data) => ContactNote.fromMap(id, data),
    )
        .where((n) => n.studentId == studentId)
        .toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
  }

  Future<void> addNote(ContactNote note) async {
    final id = note.id.isEmpty ? LocalDatabase.newId('contact_note') : note.id;
    await _box.put(id, note.toMap());
  }

  Future<void> deleteNote(String id) async {
    await _box.delete(id);
  }

  Future<void> deleteAllForStudent(String studentId) async {
    final notes = getNotesForStudentSync(studentId);
    for (final note in notes) {
      await _box.delete(note.id);
    }
  }
}
