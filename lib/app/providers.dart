import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../data/database.dart';
import '../data/repositories/backup_repository.dart';
import '../data/repositories/body_weight_repository.dart';
import '../data/repositories/exercise_repository.dart';
import '../data/repositories/routine_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/repositories/workout_repository.dart';
import '../domain/achievements.dart';
import '../domain/exercise.dart';
import '../domain/models.dart';
import '../domain/previous.dart';
import '../domain/progression.dart';
import '../domain/ranks.dart';
import '../domain/records.dart';
import '../domain/stats.dart';
import '../features/workout/active_workout_controller.dart';
import '../services/update_checker.dart';

/// Overridden in `main` (and in tests) with a real database.
final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('databaseProvider must be overridden'),
);

final workoutRepositoryProvider = Provider(
  (ref) => WorkoutRepository(ref.watch(databaseProvider)),
);
final exerciseRepositoryProvider = Provider(
  (ref) => ExerciseRepository(ref.watch(databaseProvider)),
);
final routineRepositoryProvider = Provider(
  (ref) => RoutineRepository(ref.watch(databaseProvider)),
);
final settingsRepositoryProvider = Provider(
  (ref) => SettingsRepository(ref.watch(databaseProvider)),
);
final bodyWeightRepositoryProvider = Provider(
  (ref) => BodyWeightRepository(ref.watch(databaseProvider)),
);
final backupRepositoryProvider = Provider(
  (ref) => BackupRepository(ref.watch(databaseProvider)),
);

// ---- Raw streams -----------------------------------------------------------

final profileProvider = StreamProvider<Profile>(
  (ref) => ref.watch(settingsRepositoryProvider).watchProfile(),
);

final exercisesProvider = StreamProvider<List<Exercise>>(
  (ref) => ref.watch(exerciseRepositoryProvider).watchAll(),
);

final historyProvider = StreamProvider<List<WorkoutRecord>>(
  (ref) => ref.watch(workoutRepositoryProvider).watchHistory(),
);

final routinesProvider = StreamProvider<List<RoutineWithItems>>(
  (ref) => ref.watch(routineRepositoryProvider).watchAll(),
);

final bodyWeightsProvider = StreamProvider<List<BodyWeightEntry>>(
  (ref) => ref.watch(bodyWeightRepositoryProvider).watchAll(),
);

// ---- Derived ---------------------------------------------------------------

/// Profile read before `runApp` (overridden in `main`).
final initialProfileProvider = Provider<Profile>((ref) => const Profile());

/// Synchronous view of the profile.
final currentProfileProvider = Provider<Profile>(
  (ref) =>
      ref.watch(profileProvider).value ?? ref.watch(initialProfileProvider),
);

final libraryProvider = Provider<Map<int, Exercise>>((ref) {
  final list = ref.watch(exercisesProvider).value ?? const [];
  return {for (final e in list) e.id: e};
});

final historyListProvider = Provider<List<WorkoutRecord>>(
  (ref) => ref.watch(historyProvider).value ?? const [],
);

/// Latest logged body weight, or a neutral default when none exists.
final bodyWeightProvider = Provider<double>((ref) {
  final entries = ref.watch(bodyWeightsProvider).value;
  if (entries == null || entries.isEmpty) return 75;
  return entries.first.weightKg;
});

final hasBodyWeightProvider = Provider<bool>(
  (ref) => ref.watch(bodyWeightsProvider).value?.isNotEmpty ?? false,
);

final ranksProvider = Provider<RankSummary>(
  (ref) => computeRanks(
    history: ref.watch(historyListProvider),
    library: ref.watch(libraryProvider),
    bodyWeightKg: ref.watch(bodyWeightProvider),
    sex: ref.watch(currentProfileProvider).sex,
  ),
);

final streakProvider = Provider<StreakInfo>(
  (ref) => computeStreak(
    ref.watch(historyListProvider),
    weeklyGoal: ref.watch(currentProfileProvider).weeklyGoal,
  ),
);

final levelProvider = Provider<LevelInfo>((ref) {
  final xp = ref.watch(historyListProvider).fold(0, (s, w) => s + w.xp);
  return levelForXp(xp);
});

final recordsProvider = Provider<Map<int, Map<RecordType, PersonalRecord>>>(
  (ref) => computeRecords(
    ref.watch(historyListProvider),
    ref.watch(libraryProvider),
    bodyWeightKg: ref.watch(bodyWeightProvider),
  ),
);

final recordBreaksProvider = Provider<int>(
  (ref) => countRecordBreaks(
    ref.watch(historyListProvider).reversed.toList(),
    ref.watch(libraryProvider),
    bodyWeightKg: ref.watch(bodyWeightProvider),
  ),
);

final achievementsProvider = Provider<List<AchievementProgress>>((ref) {
  final history = ref.watch(historyListProvider);
  final library = ref.watch(libraryProvider);
  var longest = Duration.zero;
  var bestSession = 0.0;
  var total = 0.0;
  for (final w in history) {
    if (w.duration > longest) longest = w.duration;
    final v = w.volume(library);
    total += v;
    if (v > bestSession) bestSession = v;
  }
  final facts = AchievementFacts(
    workouts: history.length,
    bestStreak: ref.watch(streakProvider).best,
    recordBreaks: ref.watch(recordBreaksProvider),
    totalVolumeKg: total,
    longestWorkout: longest,
    bestSessionVolumeKg: bestSession,
    earlyWorkouts: history.where((w) => w.startedAt.hour < 7).length,
    lateWorkouts: history.where((w) => w.startedAt.hour >= 22).length,
    distinctExercises: {
      for (final w in history) ...w.exercises.map((e) => e.exerciseId),
    }.length,
    ranks: ref.watch(ranksProvider),
    level: ref.watch(levelProvider),
  );
  return [for (final a in achievements) a.evaluate(facts)];
});

/// Reference performance per exercise for the workout in progress.
final previousPerformancesProvider = Provider<Map<int, PreviousPerformance>>((
  ref,
) {
  final (routineId, editingId) = ref.watch(
    activeWorkoutProvider.select((w) => (w?.routineId, w?.editingWorkoutId)),
  );
  return previousPerformances(
    ref.watch(historyListProvider),
    routineId: routineId,
    excludeWorkoutId: editingId,
  );
});

final weeklyBucketsProvider = Provider<List<WeekBucket>>(
  (ref) =>
      weeklyBuckets(ref.watch(historyListProvider), ref.watch(libraryProvider)),
);

final appVersionProvider = FutureProvider<String>(
  (ref) async => (await PackageInfo.fromPlatform()).version,
);

/// Latest GitHub release when it is newer than the running app, else null.
final updateProvider = FutureProvider<UpdateInfo?>((ref) async {
  final version = await ref.watch(appVersionProvider.future);
  return const UpdateChecker().check(version);
});
