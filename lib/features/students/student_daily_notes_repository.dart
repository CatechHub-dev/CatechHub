import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/local_database.dart';
import '../../shared/models/student_daily_note_model.dart';

final studentDailyNotesRepoProvider =
    Provider((ref) => StudentDailyNotesRepository());

class StudentDailyNotesRepository {
  final _box = LocalDatabase.studentDailyNotes();

  Stream<List<StudentDailyNote>> getNotesForStudent(String studentId) {
    return LocalDatabase.watchList(
      _box,
      (id, data) => StudentDailyNote.fromMap(id, data),
    ).map((notes) => notes
        .where((n) => n.studentId == studentId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt)));
  }

  List<StudentDailyNote> getNotesForStudentSync(String studentId) {
    return LocalDatabase.values(
      _box,
      (id, data) => StudentDailyNote.fromMap(id, data),
    )
        .where((n) => n.studentId == studentId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> addNote(StudentDailyNote note) async {
    final id = note.id.isEmpty
        ? LocalDatabase.newId('student_daily_note')
        : note.id;
    await _box.put(id, note.toMap());
  }

  Future<void> updateNote(String id, StudentDailyNote note) async {
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
