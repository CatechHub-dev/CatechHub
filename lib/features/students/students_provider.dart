import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'students_repository.dart';

final studentsRepoProvider =
    Provider<StudentsRepository>((ref) {
  return StudentsRepository();
});