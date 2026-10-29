import 'package:collection/collection.dart';
import 'package:drift/drift.dart';

import '../../domain/models.dart';
import '../database.dart';

/// Emits [load] once and again whenever any of [tables] changes.
Stream<T> watchTables<T>(
  AppDatabase db,
  List<TableInfo> tables,
  Future<T> Function() load,
) async* {
  yield await load();
  await for (final _ in db.tableUpdates(TableUpdateQuery.onAllTables(tables))) {
    yield await load();
  }
}

class WorkoutRepository {
  WorkoutRepository(this._db);
  final AppDatabase _db;

  /// Full history, newest first.
  Stream<List<WorkoutRecord>> watchHistory() => watchTables(_db, [
    _db.workouts,
    _db.workoutExercises,
    _db.workoutSets,
  ], loadHistory);

  Future<List<WorkoutRecord>> loadHistory() async {
    final workouts = await (_db.select(
      _db.workouts,
    )..orderBy([(w) => OrderingTerm.desc(w.startedAt)])).get();
    final entries = await (_db.select(
      _db.workoutExercises,
    )..orderBy([(e) => OrderingTerm.asc(e.position)])).get();
    final sets = await (_db.select(
      _db.workoutSets,
    )..orderBy([(s) => OrderingTerm.asc(s.position)])).get();

    final setsByEntry = groupBy(sets, (WorkoutSetRow s) => s.workoutExerciseId);
    final entriesByWorkout = groupBy(
      entries,
      (WorkoutExerciseRow e) => e.workoutId,
    );

    return [
      for (final w in workouts)
        WorkoutRecord(
          id: w.id,
          name: w.name,
          startedAt: w.startedAt,
          endedAt: w.endedAt,
          notes: w.notes,
          xp: w.xp,
          routineId: w.routineId,
          bodyWeightKg: w.bodyWeightKg,
          exercises: [
            for (final e in entriesByWorkout[w.id] ?? <WorkoutExerciseRow>[])
              ExerciseEntry(
                exerciseId: e.exerciseId,
                notes: e.notes,
                sets: [
                  for (final s in setsByEntry[e.id] ?? <WorkoutSetRow>[])
                    SetEntry(
                      type: s.setType,
                      weightKg: s.weightKg,
                      reps: s.reps,
                    ),
                ],
              ),
          ],
        ),
    ];
  }

  /// Inserts [workout] (its `id` is ignored) and returns the new id.
  Future<int> insert(WorkoutRecord workout) => _db.transaction(() async {
    final id = await _db.into(_db.workouts).insert(_row(workout));
    await _insertEntries(id, workout.exercises);
    return id;
  });

  /// Replaces the contents of an existing workout.
  Future<void> replace(int id, WorkoutRecord workout) =>
      _db.transaction(() async {
        await (_db.update(
          _db.workouts,
        )..where((w) => w.id.equals(id))).write(_row(workout));
        await (_db.delete(
          _db.workoutExercises,
        )..where((e) => e.workoutId.equals(id))).go();
        await _insertEntries(id, workout.exercises);
      });

  Future<void> updateDetails(int id, {String? name, String? notes}) =>
      (_db.update(_db.workouts)..where((w) => w.id.equals(id))).write(
        WorkoutsCompanion(
          name: name == null ? const Value.absent() : Value(name),
          notes: notes == null ? const Value.absent() : Value(notes),
        ),
      );

  Future<void> delete(int id) =>
      (_db.delete(_db.workouts)..where((w) => w.id.equals(id))).go();

  WorkoutsCompanion _row(WorkoutRecord w) => WorkoutsCompanion.insert(
    name: w.name,
    startedAt: w.startedAt,
    endedAt: w.endedAt,
    notes: Value(w.notes),
    xp: Value(w.xp),
    routineId: Value(w.routineId),
    bodyWeightKg: Value(w.bodyWeightKg),
  );

  Future<void> _insertEntries(
    int workoutId,
    List<ExerciseEntry> entries,
  ) async {
    for (final (i, entry) in entries.indexed) {
      final entryId = await _db
          .into(_db.workoutExercises)
          .insert(
            WorkoutExercisesCompanion.insert(
              workoutId: workoutId,
              exerciseId: entry.exerciseId,
              position: i,
              notes: Value(entry.notes),
            ),
          );
      await _db.batch(
        (b) => b.insertAll(_db.workoutSets, [
          for (final (j, s) in entry.sets.indexed)
            WorkoutSetsCompanion.insert(
              workoutExerciseId: entryId,
              position: j,
              setType: s.type,
              weightKg: s.weightKg,
              reps: s.reps,
            ),
        ]),
      );
    }
  }
}
