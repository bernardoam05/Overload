import 'package:drift/drift.dart';

import '../../domain/enums.dart';
import '../../domain/exercise.dart';
import '../database.dart';

class ExerciseDraft {
  const ExerciseDraft({
    required this.name,
    required this.primaryMuscle,
    required this.equipment,
    required this.kind,
    this.secondaryMuscles = const [],
    this.instructions = '',
    this.restSeconds,
  });

  final String name;
  final Muscle primaryMuscle;
  final List<Muscle> secondaryMuscles;
  final Equipment equipment;
  final ExerciseKind kind;
  final String instructions;
  final int? restSeconds;

  /// Validates user input; returns an error message or `null`.
  String? validate() {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'Dá um nome ao exercício.';
    if (trimmed.length > 80) return 'O nome é demasiado longo.';
    return null;
  }
}

class ExerciseRepository {
  ExerciseRepository(this._db);
  final AppDatabase _db;

  Stream<List<Exercise>> watchAll() => (_db.select(
    _db.exercises,
  )..orderBy([(e) => OrderingTerm.asc(e.name)])).watch();

  Future<int> create(ExerciseDraft draft) {
    final error = draft.validate();
    if (error != null) throw ArgumentError(error);
    return _db
        .into(_db.exercises)
        .insert(
          ExercisesCompanion.insert(
            name: draft.name.trim(),
            primaryMuscle: draft.primaryMuscle,
            secondaryMuscles: Value(draft.secondaryMuscles),
            equipment: draft.equipment,
            kind: draft.kind,
            instructions: Value(draft.instructions.trim()),
            restSeconds: Value(draft.restSeconds),
            isCustom: const Value(true),
          ),
        );
  }

  Future<void> update(int id, ExerciseDraft draft) {
    final error = draft.validate();
    if (error != null) throw ArgumentError(error);
    return (_db.update(_db.exercises)..where((e) => e.id.equals(id))).write(
      ExercisesCompanion(
        name: Value(draft.name.trim()),
        primaryMuscle: Value(draft.primaryMuscle),
        secondaryMuscles: Value(draft.secondaryMuscles),
        equipment: Value(draft.equipment),
        kind: Value(draft.kind),
        instructions: Value(draft.instructions.trim()),
        restSeconds: Value(draft.restSeconds),
      ),
    );
  }

  Future<void> setRestSeconds(int id, int? seconds) =>
      (_db.update(_db.exercises)..where((e) => e.id.equals(id))).write(
        ExercisesCompanion(restSeconds: Value(seconds)),
      );

  /// Deletes a custom exercise, or archives it when it is referenced by
  /// workouts or routines so history stays intact.
  Future<void> remove(int id) => _db.transaction(() async {
    final usedInWorkouts =
        await (_db.select(_db.workoutExercises)
              ..where((e) => e.exerciseId.equals(id))
              ..limit(1))
            .get();
    if (usedInWorkouts.isNotEmpty) {
      await (_db.delete(
        _db.routineExercises,
      )..where((e) => e.exerciseId.equals(id))).go();
      await (_db.update(_db.exercises)..where((e) => e.id.equals(id))).write(
        const ExercisesCompanion(archived: Value(true)),
      );
    } else {
      await (_db.delete(
        _db.routineExercises,
      )..where((e) => e.exerciseId.equals(id))).go();
      await (_db.delete(_db.exercises)..where((e) => e.id.equals(id))).go();
    }
  });
}
