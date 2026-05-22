import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_service.dart';
import '../../shared/models/class_model.dart';
import '../../shared/models/student_model.dart';
import '../classes/classes_provider.dart';
import '../students/students_provider.dart';
import 'documents_repository.dart';

final documentsRepoProvider = Provider((ref) => DocumentsRepository());

final myGroupStudentsProvider = StreamProvider.autoDispose<List<Student>>((ref) {
  final classesAsync = ref.watch(classesStreamProvider);
  final studentsRepo = ref.watch(studentsRepoProvider);

  return classesAsync.when(
    loading: () => Stream.value([]),
    error: (_, __) => Stream.value([]),
    data: (classes) {
      final myClass = classes.firstWhere(
        (c) => c.catechistIds.contains(AuthService.localUserId),
        orElse: () => SchoolClass(
          id: '',
          name: '',
          studentIds: [],
          catechistIds: [],
        ),
      );

      if (myClass.id.isEmpty || myClass.studentIds.isEmpty) {
        return Stream.value([]);
      }

      return studentsRepo.getAllStudents().map((allStudents) {
        return allStudents
            .where((s) => myClass.studentIds.contains(s.id))
            .toList();
      });
    },
  );
});

final documentsStreamProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.watch(documentsRepoProvider).getDocuments();
});

final documentDeliveriesProvider =
    StreamProvider.family.autoDispose<Map<String, dynamic>, String>((ref, docId) {
  return ref.watch(documentsRepoProvider).getDeliveries(docId);
});
