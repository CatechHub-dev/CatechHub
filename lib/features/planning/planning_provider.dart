import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'planning_repository.dart';

final planningRepoProvider = Provider<PlanningRepository>(
  (ref) => PlanningRepository(),
);