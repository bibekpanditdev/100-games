/// Riverpod wiring for the Daily Brain Training module.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../catalog/presentation/catalog_providers.dart';
import 'brain_training_service.dart';

final brainTrainingProvider = Provider<BrainTrainingService>(
  (ref) => BrainTrainingService(
    db: ref.watch(dbProvider).db,
    catalog: ref.watch(catalogRepoProvider),
  ),
);

final brainRoutineProvider = FutureProvider<DailyRoutine>(
  (ref) => ref.watch(brainTrainingProvider).routineFor(DateTime.now()),
);

final brainProgressProvider = FutureProvider<RoutineProgress>(
  (ref) => ref.watch(brainTrainingProvider).progressFor(DateTime.now()),
);

final brainHistoryProvider = FutureProvider<List<BrainScoreDay>>(
  (ref) => ref.watch(brainTrainingProvider).history(),
);
