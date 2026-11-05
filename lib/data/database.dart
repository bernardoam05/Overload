import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../domain/enums.dart';
import '../domain/exercise.dart';
import 'seed.dart';

part 'database.g.dart';

/// Stores a list of muscles as a comma separated list of enum names.
class MuscleListConverter extends TypeConverter<List<Muscle>, String> {
  const MuscleListConverter();

  @override
  List<Muscle> fromSql(String fromDb) => [
    for (final name in fromDb.split(','))
      if (name.isNotEmpty) Muscle.values.byName(name),
  ];

  @override
  String toSql(List<Muscle> value) => value.map((m) => m.name).join(',');
}

/// Stores a routine's planned set types as a comma separated list of names.
class SetTypeListConverter extends TypeConverter<List<SetType>, String> {
  const SetTypeListConverter();

  @override
  List<SetType> fromSql(String fromDb) => [
    for (final name in fromDb.split(',')) ?SetType.values.asNameMap()[name],
  ];

  @override
  String toSql(List<SetType> value) => value.map((t) => t.name).join(',');
}

@UseRowClass(Exercise)
class Exercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  TextColumn get primaryMuscle => textEnum<Muscle>()();
  TextColumn get secondaryMuscles =>
      text().map(const MuscleListConverter()).withDefault(const Constant(''))();
  TextColumn get equipment => textEnum<Equipment>()();
  TextColumn get kind => textEnum<ExerciseKind>()();
  RealColumn get rankFactor => real().nullable()();
  TextColumn get instructions => text().withDefault(const Constant(''))();
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();
  TextColumn get seedKey => text().nullable().unique()();
  IntColumn get restSeconds => integer().nullable()();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  TextColumn get loadMode =>
      textEnum<LoadMode>().withDefault(const Constant('bilateral'))();

  /// Equipment setup to remember (seat height, pins, grip…).
  TextColumn get setup => text().withDefault(const Constant(''))();

  /// Bench angle in degrees (negative is a decline), if the exercise uses one.
  IntColumn get benchAngle => integer().nullable()();
}

@DataClassName('WorkoutRow')
class Workouts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  IntColumn get xp => integer().withDefault(const Constant(0))();
  IntColumn get routineId => integer().nullable().references(
    Routines,
    #id,
    onDelete: KeyAction.setNull,
  )();
  RealColumn get bodyWeightKg => real().nullable()();
}

@DataClassName('WorkoutExerciseRow')
class WorkoutExercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workoutId =>
      integer().references(Workouts, #id, onDelete: KeyAction.cascade)();
  IntColumn get exerciseId => integer().references(Exercises, #id)();
  IntColumn get position => integer()();
  TextColumn get notes => text().withDefault(const Constant(''))();

  /// Done back to back with the next exercise (a superset).
  BoolColumn get supersetNext => boolean().withDefault(const Constant(false))();
}

@DataClassName('WorkoutSetRow')
class WorkoutSets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workoutExerciseId => integer().references(
    WorkoutExercises,
    #id,
    onDelete: KeyAction.cascade,
  )();
  IntColumn get position => integer()();
  TextColumn get setType => textEnum<SetType>()();
  RealColumn get weightKg => real()();
  IntColumn get reps => integer()();
}

@DataClassName('Routine')
class Routines extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  TextColumn get notes => text().withDefault(const Constant(''))();
  IntColumn get position => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get lastUsedAt => dateTime().nullable()();
}

@DataClassName('RoutineExercise')
class RoutineExercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get routineId =>
      integer().references(Routines, #id, onDelete: KeyAction.cascade)();
  IntColumn get exerciseId => integer().references(Exercises, #id)();
  IntColumn get position => integer()();
  IntColumn get sets => integer().withDefault(const Constant(3))();
  IntColumn get reps => integer().withDefault(const Constant(10))();
  RealColumn get weightKg => real().nullable()();

  /// Type of each planned set, in order. Empty (rows from before v2) means
  /// [sets] normal sets.
  TextColumn get setTypes => text()
      .map(const SetTypeListConverter())
      .withDefault(const Constant(''))();

  /// Note pinned to this exercise in the routine, shown in every workout.
  TextColumn get notes => text().withDefault(const Constant(''))();

  /// Reps fewer than the previous set for each working set after the first
  /// (0 keeps every set at [reps]).
  IntColumn get repStep => integer().withDefault(const Constant(0))();

  /// Done back to back with the next exercise (a superset).
  BoolColumn get supersetNext => boolean().withDefault(const Constant(false))();
}

@DataClassName('BodyWeightEntry')
class BodyWeights extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();
  RealColumn get weightKg => real()();
}

/// Small key/value store for settings and the in-progress workout draft.
@DataClassName('KeyValue')
class KeyValues extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

@DriftDatabase(
  tables: [
    Exercises,
    Workouts,
    WorkoutExercises,
    WorkoutSets,
    Routines,
    RoutineExercises,
    BodyWeights,
    KeyValues,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'overload'));

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(exercises, exercises.loadMode);
        await m.addColumn(routineExercises, routineExercises.setTypes);
        await m.addColumn(routineExercises, routineExercises.notes);
      }
      if (from < 3) {
        await m.addColumn(exercises, exercises.setup);
        await m.addColumn(exercises, exercises.benchAngle);
        await m.addColumn(routineExercises, routineExercises.repStep);
        await m.addColumn(routineExercises, routineExercises.supersetNext);
        await m.addColumn(workoutExercises, workoutExercises.supersetNext);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      // Adds library exercises shipped in newer versions of the app.
      await seedExercises(this);
      if (details.wasCreated) await seedRoutines(this);
    },
  );
}
