import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:overload/data/database.dart';
import 'package:overload/domain/enums.dart';
import 'package:overload/domain/exercise.dart';
import 'package:overload/domain/models.dart';

AppDatabase memoryDatabase() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase(NativeDatabase.memory());
}

Exercise exercise(
  int id, {
  String name = 'Ex',
  Muscle muscle = Muscle.chest,
  ExerciseKind kind = ExerciseKind.weighted,
  double? rankFactor = 1.0,
}) => Exercise(
  id: id,
  name: name,
  primaryMuscle: muscle,
  secondaryMuscles: const [],
  equipment: Equipment.barbell,
  kind: kind,
  rankFactor: rankFactor,
  instructions: '',
  isCustom: false,
  seedKey: null,
  restSeconds: null,
  archived: false,
);

WorkoutRecord workout(
  int id,
  DateTime start,
  Map<int, List<(double, int)>> sets, {
  int xp = 0,
  SetType type = SetType.normal,
}) => WorkoutRecord(
  id: id,
  name: 'W$id',
  startedAt: start,
  endedAt: start.add(const Duration(minutes: 60)),
  xp: xp,
  exercises: [
    for (final MapEntry(:key, :value) in sets.entries)
      ExerciseEntry(
        exerciseId: key,
        sets: [
          for (final (w, r) in value)
            SetEntry(type: type, weightKg: w, reps: r),
        ],
      ),
  ],
);
