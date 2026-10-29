import 'enums.dart';
import 'exercise.dart';
import 'models.dart';
import 'progression.dart';
import 'records.dart';

class WeekBucket {
  const WeekBucket(this.start, this.volume, this.workouts, this.sets);
  final DateTime start;
  final double volume;
  final int workouts;
  final int sets;
}

/// Totals for the last [weeks] weeks, oldest first, including empty weeks.
List<WeekBucket> weeklyBuckets(
  Iterable<WorkoutRecord> history,
  Map<int, Exercise> library, {
  int weeks = 12,
  DateTime? now,
}) {
  final current = weekStart(now ?? DateTime.now());
  final starts = [
    for (var i = weeks - 1; i >= 0; i--)
      DateTime(current.year, current.month, current.day - 7 * i),
  ];
  final volume = <DateTime, double>{};
  final count = <DateTime, int>{};
  final sets = <DateTime, int>{};
  for (final w in history) {
    final ws = weekStart(w.startedAt);
    volume[ws] = (volume[ws] ?? 0) + w.volume(library);
    count[ws] = (count[ws] ?? 0) + 1;
    sets[ws] = (sets[ws] ?? 0) + w.setCount;
  }
  return [
    for (final s in starts)
      WeekBucket(s, volume[s] ?? 0, count[s] ?? 0, sets[s] ?? 0),
  ];
}

/// Working sets per muscle since [since]. Secondary muscles count half.
Map<Muscle, double> setsPerMuscle(
  Iterable<WorkoutRecord> history,
  Map<int, Exercise> library, {
  required DateTime since,
}) {
  final result = <Muscle, double>{};
  for (final w in history.where((w) => !w.startedAt.isBefore(since))) {
    for (final entry in w.exercises) {
      final ex = library[entry.exerciseId];
      if (ex == null) continue;
      final n = entry.workingSets.length.toDouble();
      if (n == 0) continue;
      result[ex.primaryMuscle] = (result[ex.primaryMuscle] ?? 0) + n;
      for (final m in ex.secondaryMuscles) {
        result[m] = (result[m] ?? 0) + n / 2;
      }
    }
  }
  return result;
}

class ExerciseSession {
  const ExerciseSession(this.workout, this.entry);
  final WorkoutRecord workout;
  final ExerciseEntry entry;
}

/// Every time [exerciseId] was performed, newest first.
List<ExerciseSession> sessionsFor(
  Iterable<WorkoutRecord> history,
  int exerciseId,
) {
  final result = <ExerciseSession>[];
  for (final w in history) {
    for (final e in w.exercises) {
      if (e.exerciseId == exerciseId && e.sets.isNotEmpty) {
        result.add(ExerciseSession(w, e));
      }
    }
  }
  result.sort((a, b) => b.workout.startedAt.compareTo(a.workout.startedAt));
  return result;
}

class ProgressPoint {
  const ProgressPoint(this.date, this.value);
  final DateTime date;
  final double value;
}

/// The headline metric per session for charting, oldest first: estimated
/// 1RM for weighted exercises, best reps for body-weight ones and longest
/// hold for timed ones.
List<ProgressPoint> progressSeries(
  Iterable<WorkoutRecord> history,
  Exercise exercise, {
  required double bodyWeightKg,
}) {
  final type = RecordType.forKind(exercise.kind).first;
  final points = <ProgressPoint>[];
  for (final s in sessionsFor(history, exercise.id).reversed) {
    final bw = s.workout.bodyWeightKg ?? bodyWeightKg;
    var best = 0.0;
    for (final set in s.entry.workingSets) {
      final v = switch (type) {
        RecordType.e1rm => set.e1rm(exercise.kind, bw),
        _ => set.reps.toDouble(),
      };
      if (v > best) best = v;
    }
    if (best > 0) points.add(ProgressPoint(s.workout.startedAt, best));
  }
  return points;
}

/// Number of times any record was broken over the whole history.
int countRecordBreaks(
  List<WorkoutRecord> chronological,
  Map<int, Exercise> library, {
  required double bodyWeightKg,
}) {
  final best = <(int, RecordType), double>{};
  var count = 0;
  for (final w in chronological) {
    final bw = w.bodyWeightKg ?? bodyWeightKg;
    final inWorkout = <(int, RecordType), double>{};
    for (final entry in w.exercises) {
      final ex = library[entry.exerciseId];
      if (ex == null) continue;
      for (final set in entry.workingSets) {
        for (final type in RecordType.forKind(ex.kind)) {
          final v = switch (type) {
            RecordType.e1rm => set.e1rm(ex.kind, bw),
            RecordType.weight => set.weightKg,
            RecordType.volume => set.weightKg * set.reps,
            RecordType.reps || RecordType.duration => set.reps.toDouble(),
          };
          final key = (ex.id, type);
          if (v > (inWorkout[key] ?? 0)) inWorkout[key] = v;
        }
      }
    }
    inWorkout.forEach((key, v) {
      final prior = best[key];
      if (prior != null && v > prior + 1e-9) count++;
      if (prior == null || v > prior) best[key] = v;
    });
  }
  return count;
}
