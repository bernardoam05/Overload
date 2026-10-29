import 'enums.dart';
import 'exercise.dart';
import 'models.dart';

enum RecordType {
  e1rm('1RM estimado'),
  weight('Peso máximo'),
  volume('Melhor série'),
  reps('Mais repetições'),
  duration('Maior duração');

  const RecordType(this.label);
  final String label;

  static List<RecordType> forKind(ExerciseKind kind) => switch (kind) {
    ExerciseKind.weighted => const [
      RecordType.e1rm,
      RecordType.weight,
      RecordType.volume,
    ],
    ExerciseKind.bodyweight => const [RecordType.reps, RecordType.weight],
    ExerciseKind.duration => const [RecordType.duration],
    // Less assistance is progress, so "heaviest" makes no sense here.
    ExerciseKind.assisted => const [RecordType.e1rm, RecordType.reps],
  };
}

class PersonalRecord {
  const PersonalRecord({
    required this.exerciseId,
    required this.type,
    required this.value,
    required this.set,
    required this.workoutId,
    required this.achievedAt,
  });

  final int exerciseId;
  final RecordType type;
  final double value;
  final SetEntry set;
  final int workoutId;
  final DateTime achievedAt;
}

double _valueOf(RecordType type, SetEntry set, ExerciseKind kind, double bw) =>
    switch (type) {
      RecordType.e1rm => set.e1rm(kind, bw),
      RecordType.weight => set.weightKg,
      RecordType.volume => set.weightKg * set.reps,
      RecordType.reps => set.reps.toDouble(),
      RecordType.duration => set.reps.toDouble(),
    };

/// Best value of each record type achieved in a single workout entry.
Map<RecordType, PersonalRecord> _bestInEntry(
  WorkoutRecord workout,
  ExerciseEntry entry,
  Exercise exercise,
  double bodyWeightKg,
) {
  final bw = workout.bodyWeightKg ?? bodyWeightKg;
  final result = <RecordType, PersonalRecord>{};
  for (final set in entry.workingSets) {
    for (final type in RecordType.forKind(exercise.kind)) {
      final value = _valueOf(type, set, exercise.kind, bw);
      if (value <= 0) continue;
      final current = result[type];
      if (current == null || value > current.value) {
        result[type] = PersonalRecord(
          exerciseId: exercise.id,
          type: type,
          value: value,
          set: set,
          workoutId: workout.id,
          achievedAt: workout.startedAt,
        );
      }
    }
  }
  return result;
}

/// All-time records per exercise.
Map<int, Map<RecordType, PersonalRecord>> computeRecords(
  Iterable<WorkoutRecord> history,
  Map<int, Exercise> library, {
  required double bodyWeightKg,
}) {
  final records = <int, Map<RecordType, PersonalRecord>>{};
  for (final workout in history) {
    for (final entry in workout.exercises) {
      final exercise = library[entry.exerciseId];
      if (exercise == null) continue;
      final best = _bestInEntry(workout, entry, exercise, bodyWeightKg);
      final current = records.putIfAbsent(exercise.id, () => {});
      best.forEach((type, record) {
        final existing = current[type];
        if (existing == null ||
            record.value > existing.value ||
            (record.value == existing.value &&
                record.achievedAt.isBefore(existing.achievedAt))) {
          current[type] = record;
        }
      });
    }
  }
  return records;
}

/// Records set by [workout] compared with [previous] workouts. An exercise
/// performed for the first time sets no records.
List<PersonalRecord> newRecords(
  WorkoutRecord workout,
  Iterable<WorkoutRecord> previous,
  Map<int, Exercise> library, {
  required double bodyWeightKg,
}) {
  final before = computeRecords(
    previous.where(
      (w) => w.id != workout.id && w.startedAt.isBefore(workout.startedAt),
    ),
    library,
    bodyWeightKg: bodyWeightKg,
  );
  final result = <PersonalRecord>[];
  final seen = <int>{};
  for (final entry in workout.exercises) {
    final exercise = library[entry.exerciseId];
    final prior = before[entry.exerciseId];
    if (exercise == null || prior == null || !seen.add(exercise.id)) continue;
    final merged = <RecordType, PersonalRecord>{};
    for (final e in workout.exercises.where(
      (e) => e.exerciseId == exercise.id,
    )) {
      _bestInEntry(workout, e, exercise, bodyWeightKg).forEach((type, r) {
        if ((merged[type]?.value ?? 0) < r.value) merged[type] = r;
      });
    }
    merged.forEach((type, record) {
      final old = prior[type];
      if (old == null || record.value > old.value + 1e-9) result.add(record);
    });
  }
  return result;
}
