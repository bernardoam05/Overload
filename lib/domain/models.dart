import 'enums.dart';
import 'exercise.dart';
import 'one_rm.dart';

/// A completed set, as stored in the log.
class SetEntry {
  const SetEntry({
    required this.type,
    required this.weightKg,
    required this.reps,
  });

  final SetType type;

  /// External load in kg. For body-weight exercises this is the *added* load.
  final double weightKg;

  /// Repetitions, or seconds for duration exercises.
  final int reps;

  double volume(ExerciseKind kind) =>
      kind == ExerciseKind.weighted && type.isWorking ? weightKg * reps : 0;

  /// Estimated 1RM using the effective load (body weight included where it
  /// applies).
  double e1rm(ExerciseKind kind, double bodyWeightKg) => switch (kind) {
    ExerciseKind.weighted => estimateOneRepMax(weightKg, reps),
    ExerciseKind.bodyweight => estimateOneRepMax(bodyWeightKg + weightKg, reps),
    ExerciseKind.duration => 0,
    ExerciseKind.assisted => estimateOneRepMax(
      (bodyWeightKg - weightKg).clamp(0, double.infinity).toDouble(),
      reps,
    ),
  };

  Map<String, Object?> toJson() => {
    'type': type.name,
    'weightKg': weightKg,
    'reps': reps,
  };

  factory SetEntry.fromJson(Map<String, Object?> json) => SetEntry(
    type: SetType.values.byName(json['type']! as String),
    weightKg: (json['weightKg']! as num).toDouble(),
    reps: (json['reps']! as num).toInt(),
  );
}

class ExerciseEntry {
  const ExerciseEntry({
    required this.exerciseId,
    required this.sets,
    this.notes = '',
  });

  final int exerciseId;
  final List<SetEntry> sets;
  final String notes;

  Iterable<SetEntry> get workingSets => sets.where((s) => s.type.isWorking);
}

/// A finished workout with all its exercises and sets.
class WorkoutRecord {
  const WorkoutRecord({
    required this.id,
    required this.name,
    required this.startedAt,
    required this.endedAt,
    required this.exercises,
    this.notes = '',
    this.xp = 0,
    this.routineId,
    this.bodyWeightKg,
  });

  final int id;
  final String name;
  final DateTime startedAt;
  final DateTime endedAt;
  final List<ExerciseEntry> exercises;
  final String notes;
  final int xp;
  final int? routineId;
  final double? bodyWeightKg;

  Duration get duration => endedAt.difference(startedAt);

  int get setCount => exercises.fold(0, (sum, e) => sum + e.workingSets.length);

  double volume(Map<int, Exercise> library) {
    var total = 0.0;
    for (final entry in exercises) {
      final kind = library[entry.exerciseId]?.kind ?? ExerciseKind.weighted;
      for (final set in entry.sets) {
        total += set.volume(kind);
      }
    }
    return total;
  }
}
