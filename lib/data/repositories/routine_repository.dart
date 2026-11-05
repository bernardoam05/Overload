import 'package:collection/collection.dart';
import 'package:drift/drift.dart';

import '../../domain/enums.dart';
import '../database.dart';
import 'workout_repository.dart';

/// One exercise of a routine: the planned sets (by type), the target reps
/// and load for working sets, and a note pinned to it.
class RoutineItem {
  RoutineItem({
    required this.exerciseId,
    List<SetType>? setTypes,
    int sets = 3,
    this.reps = 10,
    this.weightKg,
    this.notes = '',
    int repStep = 0,
    this.supersetNext = false,
  }) : repStep = repStep.clamp(0, maxRepStep),
       setTypes = List.unmodifiable(
         setTypes == null || setTypes.isEmpty
             ? List.filled(sets.clamp(1, maxSets), SetType.normal)
             : setTypes.take(maxSets),
       );

  static const maxSets = 20;
  static const maxRepStep = 3;

  final int exerciseId;

  /// Type of each planned set, in order; never empty.
  final List<SetType> setTypes;
  final int reps;
  final double? weightKg;
  final String notes;

  /// Reps fewer than the previous working set, for each working set after
  /// the first: with 10 reps and a step of 1 the plan is 10 · 9 · 8.
  final int repStep;

  /// Done back to back with the next exercise (a superset).
  final bool supersetNext;

  int get sets => setTypes.length;

  /// Target reps for each planned set (`null` for warm-ups and drops).
  List<int?> get targets => plannedTargets(setTypes, reps, repStep);

  RoutineItem copyWith({
    int? exerciseId,
    List<SetType>? setTypes,
    int? reps,
    double? Function()? weightKg,
    String? notes,
    int? repStep,
    bool? supersetNext,
  }) => RoutineItem(
    exerciseId: exerciseId ?? this.exerciseId,
    setTypes: setTypes ?? this.setTypes,
    reps: reps ?? this.reps,
    weightKg: weightKg == null ? this.weightKg : weightKg(),
    notes: notes ?? this.notes,
    repStep: repStep ?? this.repStep,
    supersetNext: supersetNext ?? this.supersetNext,
  );
}

/// Target reps per planned set: the main sets (normal and to failure) start
/// at [reps] and drop by [step] each (never below 1); warm-ups and drops
/// have no target.
List<int?> plannedTargets(List<SetType> types, int reps, int step) {
  var k = 0;
  return [
    for (final t in types)
      if (t == SetType.normal || t == SetType.failure)
        (reps - step * k++).clamp(1, 999)
      else
        null,
  ];
}

/// "10 reps" or "10 · 9 · 8 reps" (main sets only).
String describeTargets(RoutineItem item, {bool seconds = false}) {
  final values = item.targets.whereType<int>().toList();
  final unit = seconds ? 's' : ' reps';
  if (values.isEmpty) return '';
  if (item.repStep == 0 || values.length == 1) return '${values.first}$unit';
  return '${values.join(' · ')}$unit';
}

/// "1 aquecimento + 3 séries + 1 drop" (types counted, in a fixed order).
String describeSetTypes(List<SetType> types) {
  int count(SetType t) => types.where((x) => x == t).length;
  final warmup = count(SetType.warmup);
  final normal = count(SetType.normal);
  final failure = count(SetType.failure);
  final drop = count(SetType.drop);
  return [
    if (warmup > 0) '$warmup ${warmup == 1 ? 'aquecimento' : 'aquecimentos'}',
    if (normal > 0) '$normal ${normal == 1 ? 'série' : 'séries'}',
    if (failure > 0) '$failure até à falha',
    if (drop > 0) '$drop drop',
  ].join(' + ');
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
              setTypes: e.setTypes,
              sets: e.sets,
              reps: e.reps,
              weightKg: e.weightKg,
              notes: e.notes,
              repStep: e.repStep,
              supersetNext: e.supersetNext,
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
              sets: Value(item.sets),
              setTypes: Value(item.setTypes),
              reps: Value(item.reps.clamp(1, 999)),
              weightKg: Value(item.weightKg),
              notes: Value(item.notes.trim()),
              repStep: Value(item.repStep),
              supersetNext: Value(item.supersetNext),
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
