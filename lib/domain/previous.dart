import 'enums.dart';
import 'models.dart';

/// The last time an exercise was performed, used as today's reference.
class PreviousPerformance {
  PreviousPerformance(this.workout, this.entry);

  final WorkoutRecord workout;
  final ExerciseEntry entry;

  late final List<SetEntry> warmups = [
    for (final s in entry.sets)
      if (s.type == SetType.warmup) s,
  ];
  late final List<SetEntry> working = entry.workingSets.toList();

  /// Matches warm-ups with warm-ups and working sets with working sets, so
  /// adding or removing a warm-up does not shift the comparison.
  SetEntry? match(SetType type, int warmupIndex, int workingIndex) {
    final list = type == SetType.warmup ? warmups : working;
    final i = type == SetType.warmup ? warmupIndex : workingIndex;
    return i >= 0 && i < list.length ? list[i] : null;
  }
}

/// Reference performance per exercise.
///
/// Prefers the last session of the same routine (within [routineWindow]):
/// alternating heavy and light days on the same lift is common, and the
/// comparable reference for "Pernas B" is the last "Pernas B", not the
/// last time the lift appeared anywhere. Falls back to the latest session.
Map<int, PreviousPerformance> previousPerformances(
  List<WorkoutRecord> newestFirst, {
  int? routineId,
  int? excludeWorkoutId,
  DateTime? now,
  Duration routineWindow = const Duration(days: 56),
}) {
  final cutoff = (now ?? DateTime.now()).subtract(routineWindow);
  final latest = <int, PreviousPerformance>{};
  final sameRoutine = <int, PreviousPerformance>{};
  for (final w in newestFirst) {
    if (w.id == excludeWorkoutId) continue;
    final inRoutine =
        routineId != null &&
        w.routineId == routineId &&
        w.startedAt.isAfter(cutoff);
    for (final e in w.exercises) {
      if (e.sets.isEmpty) continue;
      latest.putIfAbsent(e.exerciseId, () => PreviousPerformance(w, e));
      if (inRoutine) {
        sameRoutine.putIfAbsent(e.exerciseId, () => PreviousPerformance(w, e));
      }
    }
  }
  return {...latest, ...sameRoutine};
}

/// Single number to compare two sets of the same exercise: estimated 1RM
/// (body weight included where it applies) or seconds held.
double setStrength(SetEntry s, ExerciseKind kind, double bodyWeightKg) =>
    switch (kind) {
      ExerciseKind.duration => s.reps.toDouble(),
      _ => s.e1rm(kind, bodyWeightKg),
    };

/// 1 if [now] beats [before], -1 if it is weaker, 0 if equivalent (within
/// half a percent, so rounding does not flag a change).
int compareSets(
  SetEntry now,
  SetEntry before,
  ExerciseKind kind,
  double bodyWeightKg,
) {
  final a = setStrength(now, kind, bodyWeightKg);
  final b = setStrength(before, kind, bodyWeightKg);
  final c = _compareRatio(a, b);
  if (c != 0 || kind == ExerciseKind.duration) return c;
  // Same estimated max (e.g. reps beyond the estimate cap): more total work wins.
  double load(SetEntry s) => switch (kind) {
    ExerciseKind.bodyweight => bodyWeightKg + s.weightKg,
    ExerciseKind.assisted => bodyWeightKg - s.weightKg,
    _ => s.weightKg,
  };
  return _compareRatio(load(now) * now.reps, load(before) * before.reps);
}

int _compareRatio(double a, double b) {
  if (b <= 0) return a > 0 ? 1 : 0;
  final ratio = a / b;
  if (ratio > 1.005) return 1;
  if (ratio < 0.995) return -1;
  return 0;
}
