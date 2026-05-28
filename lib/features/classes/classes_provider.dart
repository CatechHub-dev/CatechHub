import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'classes_repository.dart';

final classesRepoProvider =
    Provider((ref) => ClassesRepository());

final classesStreamProvider = StreamProvider((ref) {
  final repo = ref.watch(classesRepoProvider);
  return repo.getClasses();
});