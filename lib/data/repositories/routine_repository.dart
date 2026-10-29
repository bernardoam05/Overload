import 'package:collection/collection.dart';
import 'package:drift/drift.dart';

import '../database.dart';
import 'workout_repository.dart';

class RoutineItem {
  const RoutineItem({
    required this.exerciseId,
    this.sets = 3,
    this.reps = 10,
    this.weightKg,
  });

  final int exerciseId;
  final int sets;
  final int reps;
  final double? weightKg;

  RoutineItem copyWith({int? sets, int? reps, double? weightKg}) => RoutineItem(
    exerciseId: exerciseId,
    sets: sets ?? this.sets,
    reps: reps ?? this.reps,
    weightKg: weightKg ?? this.weightKg,
  );
}

class RoutineWithItems {
  const RoutineWithItems(this.routine, this.items);
  final Routine routine;
  final List<RoutineItem> items;
}

class RoutineRepository {
  RoutineRepository(this._db);
  final AppDatabase _db;

  Stream<List<RoutineWithItems>> watchAll() =>
      watchTables(_db, [_db.routines, _db.routineExercises], _loadAll);

  Future<List<RoutineWithItems>> _loadAll() async {
    final routines =
        await (_db.select(_db.routines)..orderBy([
              (r) => OrderingTerm.asc(r.position),
              (r) => OrderingTerm.asc(r.id),
            ]))
            .get();
    final items = await (_db.select(
      _db.routineExercises,
    )..orderBy([(e) => OrderingTerm.asc(e.position)])).get();
    final byRoutine = groupBy(items, (RoutineExercise e) => e.routineId);
    return [
      for (final r in routines)
        RoutineWithItems(r, [
          for (final e in byRoutine[r.id] ?? <RoutineExercise>[])
            RoutineItem(
              exerciseId: e.exerciseId,
              sets: e.sets,
              reps: e.reps,
              weightKg: e.weightKg,
            ),
        ]),
    ];
  }

  /// Creates (when [id] is null) or updates a routine; returns its id.
  Future<int> save({
    int? id,
    required String name,
    String notes = '',
    required List<RoutineItem> items,
  }) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('Dá um nome à rotina.');
    return _db.transaction(() async {
      final int routineId;
      if (id == null) {
        final count = await _db.routines.count().getSingle();
        routineId = await _db
            .into(_db.routines)
            .insert(
              RoutinesCompanion.insert(
                name: trimmed,
                notes: Value(notes),
                position: Value(count),
                createdAt: DateTime.now(),
              ),
            );
      } else {
        routineId = id;
        await (_db.update(_db.routines)..where((r) => r.id.equals(id))).write(
          RoutinesCompanion(name: Value(trimmed), notes: Value(notes)),
        );
        await (_db.delete(
          _db.routineExercises,
        )..where((e) => e.routineId.equals(id))).go();
      }
      await _db.batch(
        (b) => b.insertAll(_db.routineExercises, [
          for (final (i, item) in items.indexed)
            RoutineExercisesCompanion.insert(
              routineId: routineId,
              exerciseId: item.exerciseId,
              position: i,
              sets: Value(item.sets.clamp(1, 20)),
              reps: Value(item.reps.clamp(1, 999)),
              weightKg: Value(item.weightKg),
            ),
        ]),
      );
      return routineId;
    });
  }

  Future<void> markUsed(int id) =>
      (_db.update(_db.routines)..where((r) => r.id.equals(id))).write(
        RoutinesCompanion(lastUsedAt: Value(DateTime.now())),
      );

  Future<void> delete(int id) =>
      (_db.delete(_db.routines)..where((r) => r.id.equals(id))).go();

  Future<void> reorder(List<int> orderedIds) => _db.batch((b) {
    for (final (i, id) in orderedIds.indexed) {
      b.update(
        _db.routines,
        RoutinesCompanion(position: Value(i)),
        where: (r) => r.id.equals(id),
      );
    }
  });
}
