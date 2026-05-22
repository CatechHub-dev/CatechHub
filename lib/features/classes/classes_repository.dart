import '../../core/storage/local_database.dart';
import '../../shared/models/class_model.dart';

class ClassesRepository {
  final _box = LocalDatabase.classes();

  Stream<List<SchoolClass>> getClasses() {
    return LocalDatabase.watchList(
      _box,
      (id, data) => SchoolClass.fromMap(id, data),
    );
  }

  List<SchoolClass> getClassesSync() {
    return LocalDatabase.values(
      _box,
      (id, data) => SchoolClass.fromMap(id, data),
    );
  }

  Future<void> addClass(SchoolClass c) async {
    final id = c.id.isEmpty ? LocalDatabase.newId('class') : c.id;
    await _box.put(id, c.copyWith(id: id).toMap());
  }

  Future<void> updateClass(String id, SchoolClass c) async {
    final previous = _getClass(id);
    await _box.put(id, c.copyWith(id: id).toMap());

    if (previous == null) return;

    final removedStudentIds = previous.studentIds
        .where((studentId) => !c.studentIds.contains(studentId))
        .toList();
    if (removedStudentIds.isEmpty) return;

    final attendanceBox = LocalDatabase.attendance();
    for (final attendanceKey in attendanceBox.keys) {
      final data = LocalDatabase.toStringDynamicMap(attendanceBox.get(attendanceKey));
      if (data['classId'] != id) continue;

      final presence = Map<String, dynamic>.from(data['presence'] as Map? ?? {});
      var changed = false;
      for (final studentId in removedStudentIds) {
        changed = presence.remove(studentId) != null || changed;
      }

      if (changed) {
        data['presence'] = presence;
        await attendanceBox.put(attendanceKey, data);
      }
    }
  }

  Future<void> deleteClass(String id) async {
    await _box.delete(id);

    final planningBox = LocalDatabase.planning();
    final meetingIds = planningBox.keys.where((key) {
      final data = LocalDatabase.toStringDynamicMap(planningBox.get(key));
      return data['classId'] == id;
    }).toList();

    for (final meetingId in meetingIds) {
      await planningBox.delete(meetingId);
      await LocalDatabase.attendance().delete(meetingId);
    }

    final attendanceBox = LocalDatabase.attendance();
    final orphanAttendanceIds = attendanceBox.keys.where((key) {
      final data = LocalDatabase.toStringDynamicMap(attendanceBox.get(key));
      return data['classId'] == id;
    }).toList();

    for (final attendanceId in orphanAttendanceIds) {
      await attendanceBox.delete(attendanceId);
    }
  }

  Future<void> addStudentToClass(String classId, String studentId) async {
    final current = _getClass(classId);
    if (current == null || current.studentIds.contains(studentId)) return;
    await updateClass(
      classId,
      current.copyWith(studentIds: [...current.studentIds, studentId]),
    );
  }

  Future<void> removeStudentFromClass(String classId, String studentId) async {
    final current = _getClass(classId);
    if (current == null) return;
    await updateClass(
      classId,
      current.copyWith(
        studentIds: current.studentIds.where((id) => id != studentId).toList(),
      ),
    );
  }

  Future<void> addCatechistToClass(String classId, String catechistId) async {
    final current = _getClass(classId);
    if (current == null || current.catechistIds.contains(catechistId)) return;
    await updateClass(
      classId,
      current.copyWith(catechistIds: [...current.catechistIds, catechistId]),
    );
  }

  Future<void> removeCatechistFromClass(String classId, String catechistId) async {
    final current = _getClass(classId);
    if (current == null) return;
    await updateClass(
      classId,
      current.copyWith(
        catechistIds:
            current.catechistIds.where((id) => id != catechistId).toList(),
      ),
    );
  }

  SchoolClass? _getClass(String id) {
    final data = _box.get(id);
    if (data == null) return null;
    return SchoolClass.fromMap(id, LocalDatabase.toStringDynamicMap(data));
  }
}
