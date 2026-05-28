import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/local_database.dart';
import '../../shared/models/attachment_parent_type.dart';
import '../../shared/models/student_model.dart';
import '../../shared/utils/name_formatting.dart';
import '../attachments/attachments_repository.dart';

final studentsRepositoryProvider =
    Provider<StudentsRepository>((ref) {
  return StudentsRepository();
});

class StudentsRepository {
  final _box = LocalDatabase.students();

  Future<void> addStudent(Student student) async {
    final id = student.id.isEmpty ? LocalDatabase.newId('student') : student.id;
    await _box.put(id, _normalize(student).toMap());
  }

  Stream<List<Student>> getAllStudents() {
    return LocalDatabase.watchList(
      _box,
      (id, data) => Student.fromMap(id, data),
    ).map(Student.sortedBySurname);
  }

  Stream<List<Student>> getStudents() => getAllStudents();

  List<Student> getAllStudentsSync() {
    return Student.sortedBySurname(
      LocalDatabase.values(
        _box,
        (id, data) => Student.fromMap(id, data),
      ),
    );
  }

  Future<void> updateStudent(String id, Student student) async {
    await _box.put(id, _normalize(student).toMap());
  }

  Student _normalize(Student student) {
    return Student(
      id: student.id,
      name: NameFormatting.capitalizeWords(student.name),
      surname: NameFormatting.capitalizeWords(student.surname),
      birthDate: student.birthDate,
      classId: student.classId,
      motherName: NameFormatting.capitalizeWords(student.motherName),
      motherSurname: NameFormatting.capitalizeWords(student.motherSurname),
      fatherName: NameFormatting.capitalizeWords(student.fatherName),
      fatherSurname: NameFormatting.capitalizeWords(student.fatherSurname),
      motherPhone: student.motherPhone.trim(),
      fatherPhone: student.fatherPhone.trim(),
      studentPhone: student.studentPhone.trim(),
      allergies: student.allergies?.trim().isEmpty == true
          ? null
          : student.allergies?.trim(),
      autonomousExits: student.autonomousExits,
      notes: student.notes?.trim().isEmpty == true ? null : student.notes?.trim(),
    );
  }

  Future<void> deleteStudent(String id) async {
    await AttachmentsRepository().deleteAllForParent(
      parentId: id,
      parentType: AttachmentParentType.student,
    );
    await _box.delete(id);

    final classesBox = LocalDatabase.classes();
    for (final classKey in classesBox.keys) {
      final data = LocalDatabase.toStringDynamicMap(classesBox.get(classKey));
      final studentIds = (data['studentIds'] as List? ?? [])
          .map((value) => value.toString())
          .where((studentId) => studentId != id)
          .toList();
      data['studentIds'] = studentIds;
      await classesBox.put(classKey, data);
    }

    final attendanceBox = LocalDatabase.attendance();
    for (final attendanceKey in attendanceBox.keys) {
      final data = LocalDatabase.toStringDynamicMap(attendanceBox.get(attendanceKey));
      final presence = Map<String, dynamic>.from(data['presence'] as Map? ?? {});
      if (presence.remove(id) != null) {
        data['presence'] = presence;
        await attendanceBox.put(attendanceKey, data);
      }
    }

    final deliveriesBox = LocalDatabase.documentDeliveries();
    for (final deliveryKey in deliveriesBox.keys) {
      final data = LocalDatabase.toStringDynamicMap(deliveriesBox.get(deliveryKey));
      if (data.remove(id) != null) {
        await deliveriesBox.put(deliveryKey, data);
      }
    }
  }
}


