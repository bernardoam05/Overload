import '../../domain/enums.dart';

int _seq = 0;
String newLocalId() => '${DateTime.now().microsecondsSinceEpoch}-${_seq++}';

/// A set being edited during a workout. Values stay nullable until the user
/// types them, so the "previous" hint can be shown as a placeholder.
class ActiveSet {
  const ActiveSet({
    required this.id,
    this.type = SetType.normal,
    this.weightKg,
    this.reps,
    this.done = false,
  });

  final String id;
  final SetType type;
  final double? weightKg;
  final int? reps;
  final bool done;

  ActiveSet copyWith({
    SetType? type,
    double? Function()? weightKg,
    int? Function()? reps,
    bool? done,
  }) => ActiveSet(
    id: id,
    type: type ?? this.type,
    weightKg: weightKg == null ? this.weightKg : weightKg(),
    reps: reps == null ? this.reps : reps(),
    done: done ?? this.done,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'type': type.name,
    'weightKg': weightKg,
    'reps': reps,
    'done': done,
  };

  factory ActiveSet.fromJson(Map<String, Object?> j) => ActiveSet(
    id: j['id'] as String? ?? newLocalId(),
    type: SetType.values.asNameMap()[j['type']] ?? SetType.normal,
    weightKg: (j['weightKg'] as num?)?.toDouble(),
    reps: (j['reps'] as num?)?.toInt(),
    done: j['done'] == true,
  );
}

class ActiveExercise {
  const ActiveExercise({
    required this.id,
    required this.exerciseId,
    required this.sets,
    this.notes = '',
  });

  final String id;
  final int exerciseId;
  final List<ActiveSet> sets;
  final String notes;

  int get doneCount => sets.where((s) => s.done).length;

  ActiveExercise copyWith({
    int? exerciseId,
    List<ActiveSet>? sets,
    String? notes,
  }) => ActiveExercise(
    id: id,
    exerciseId: exerciseId ?? this.exerciseId,
    sets: sets ?? this.sets,
    notes: notes ?? this.notes,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'exerciseId': exerciseId,
    'notes': notes,
    'sets': [for (final s in sets) s.toJson()],
  };

  factory ActiveExercise.fromJson(Map<String, Object?> j) => ActiveExercise(
    id: j['id'] as String? ?? newLocalId(),
    exerciseId: (j['exerciseId']! as num).toInt(),
    notes: j['notes'] as String? ?? '',
    sets: [
      for (final s in (j['sets'] as List? ?? const []))
        ActiveSet.fromJson((s as Map).cast<String, Object?>()),
    ],
  );
}

class ActiveWorkout {
  const ActiveWorkout({
    required this.name,
    required this.startedAt,
    required this.exercises,
    this.notes = '',
    this.routineId,
    this.editingWorkoutId,
    this.editingEndedAt,
    this.restEndsAt,
    this.restTotalSeconds = 0,
  });

  final String name;
  final DateTime startedAt;
  final List<ActiveExercise> exercises;
  final String notes;
  final int? routineId;

  /// Set when an already finished workout is being edited.
  final int? editingWorkoutId;
  final DateTime? editingEndedAt;

  final DateTime? restEndsAt;
  final int restTotalSeconds;

  bool get isEditing => editingWorkoutId != null;

  int get doneSets => exercises.fold(0, (s, e) => s + e.doneCount);

  ActiveWorkout copyWith({
    String? name,
    List<ActiveExercise>? exercises,
    String? notes,
    DateTime? Function()? restEndsAt,
    int? restTotalSeconds,
  }) => ActiveWorkout(
    name: name ?? this.name,
    startedAt: startedAt,
    exercises: exercises ?? this.exercises,
    notes: notes ?? this.notes,
    routineId: routineId,
    editingWorkoutId: editingWorkoutId,
    editingEndedAt: editingEndedAt,
    restEndsAt: restEndsAt == null ? this.restEndsAt : restEndsAt(),
    restTotalSeconds: restTotalSeconds ?? this.restTotalSeconds,
  );

  Map<String, Object?> toJson() => {
    'name': name,
    'startedAt': startedAt.toIso8601String(),
    'notes': notes,
    'routineId': routineId,
    'editingWorkoutId': editingWorkoutId,
    'editingEndedAt': editingEndedAt?.toIso8601String(),
    'restEndsAt': restEndsAt?.toIso8601String(),
    'restTotalSeconds': restTotalSeconds,
    'exercises': [for (final e in exercises) e.toJson()],
  };

  factory ActiveWorkout.fromJson(Map<String, Object?> j) => ActiveWorkout(
    name: j['name'] as String? ?? 'Treino',
    startedAt: DateTime.parse(j['startedAt']! as String),
    notes: j['notes'] as String? ?? '',
    routineId: (j['routineId'] as num?)?.toInt(),
    editingWorkoutId: (j['editingWorkoutId'] as num?)?.toInt(),
    editingEndedAt: j['editingEndedAt'] == null
        ? null
        : DateTime.parse(j['editingEndedAt']! as String),
    restEndsAt: j['restEndsAt'] == null
        ? null
        : DateTime.parse(j['restEndsAt']! as String),
    restTotalSeconds: (j['restTotalSeconds'] as num?)?.toInt() ?? 0,
    exercises: [
      for (final e in (j['exercises'] as List? ?? const []))
        ActiveExercise.fromJson((e as Map).cast<String, Object?>()),
    ],
  );
}
