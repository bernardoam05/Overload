import 'package:flutter_test/flutter_test.dart';
import 'package:overload/data/database.dart';
import 'package:overload/data/repositories/backup_repository.dart';
import 'package:overload/data/repositories/body_weight_repository.dart';
import 'package:overload/data/repositories/exercise_repository.dart';
import 'package:overload/data/repositories/routine_repository.dart';
import 'package:overload/data/repositories/settings_repository.dart';
import 'package:overload/data/repositories/workout_repository.dart';
import 'package:overload/data/seed.dart';
import 'package:overload/domain/enums.dart';
import 'package:overload/domain/models.dart';

import '../helpers.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = memoryDatabase());
  tearDown(() => db.close());

  test('seeds the exercise library and example routines', () async {
    final exercises = await db.select(db.exercises).get();
    expect(exercises, hasLength(librarySeed.length));
    expect(exercises.where((e) => e.rankFactor != null), isNotEmpty);
    final routines = await RoutineRepository(db).watchAll().first;
    expect(routines, isNotEmpty);
    expect(routines.first.items, isNotEmpty);
  });

  test('seeding again does not duplicate exercises', () async {
    await seedExercises(db);
    expect(await db.select(db.exercises).get(), hasLength(librarySeed.length));
  });

  test('workouts round-trip with exercises and sets in order', () async {
    final repo = WorkoutRepository(db);
    final ids = (await db.select(db.exercises).get()).map((e) => e.id).toList();
    final id = await repo.insert(
      WorkoutRecord(
        id: -1,
        name: 'Push',
        startedAt: DateTime(2026, 10, 20, 18),
        endedAt: DateTime(2026, 10, 20, 19),
        xp: 120,
        exercises: [
          ExerciseEntry(
            exerciseId: ids[0],
            notes: 'boa',
            sets: const [
              SetEntry(type: SetType.warmup, weightKg: 40, reps: 10),
              SetEntry(type: SetType.normal, weightKg: 80, reps: 5),
            ],
          ),
          ExerciseEntry(
            exerciseId: ids[1],
            sets: const [
              SetEntry(type: SetType.failure, weightKg: 30, reps: 12),
            ],
          ),
        ],
      ),
    );

    final history = await repo.loadHistory();
    expect(history, hasLength(1));
    final w = history.single;
    expect(w.id, id);
    expect(w.xp, 120);
    expect(w.exercises.map((e) => e.exerciseId), [ids[0], ids[1]]);
    expect(w.exercises.first.notes, 'boa');
    expect(w.exercises.first.sets.map((s) => s.weightKg), [40, 80]);
    expect(w.exercises.last.sets.single.type, SetType.failure);
  });

  test('replacing a workout rewrites its sets', () async {
    final repo = WorkoutRepository(db);
    final exId = (await db.select(db.exercises).get()).first.id;
    WorkoutRecord make(double kg) => WorkoutRecord(
      id: -1,
      name: 'A',
      startedAt: DateTime(2026, 1, 1),
      endedAt: DateTime(2026, 1, 1, 1),
      exercises: [
        ExerciseEntry(
          exerciseId: exId,
          sets: [SetEntry(type: SetType.normal, weightKg: kg, reps: 5)],
        ),
      ],
    );
    final id = await repo.insert(make(50));
    await repo.replace(id, make(60));
    final w = (await repo.loadHistory()).single;
    expect(w.exercises.single.sets.single.weightKg, 60);
    expect(await db.select(db.workoutSets).get(), hasLength(1));
  });

  test('deleting a workout cascades to its sets', () async {
    final repo = WorkoutRepository(db);
    final exId = (await db.select(db.exercises).get()).first.id;
    final id = await repo.insert(
      WorkoutRecord(
        id: -1,
        name: 'A',
        startedAt: DateTime(2026, 1, 1),
        endedAt: DateTime(2026, 1, 1, 1),
        exercises: [
          ExerciseEntry(
            exerciseId: exId,
            sets: const [SetEntry(type: SetType.normal, weightKg: 1, reps: 1)],
          ),
        ],
      ),
    );
    await repo.delete(id);
    expect(await db.select(db.workoutSets).get(), isEmpty);
    expect(await db.select(db.workoutExercises).get(), isEmpty);
  });

  test('custom exercises are archived instead of deleted when used', () async {
    final exercises = ExerciseRepository(db);
    const draft = ExerciseDraft(
      name: '  Meu exercício ',
      primaryMuscle: Muscle.biceps,
      equipment: Equipment.cable,
      kind: ExerciseKind.weighted,
    );
    final unused = await exercises.create(draft);
    final used = await exercises.create(draft);
    await WorkoutRepository(db).insert(
      WorkoutRecord(
        id: -1,
        name: 'A',
        startedAt: DateTime(2026, 1, 1),
        endedAt: DateTime(2026, 1, 1, 1),
        exercises: [
          ExerciseEntry(
            exerciseId: used,
            sets: const [
              SetEntry(type: SetType.normal, weightKg: 10, reps: 10),
            ],
          ),
        ],
      ),
    );
    await exercises.remove(unused);
    await exercises.remove(used);
    final all = await exercises.watchAll().first;
    expect(all.where((e) => e.id == unused), isEmpty);
    final archived = all.singleWhere((e) => e.id == used);
    expect(archived.archived, isTrue);
    expect(archived.name, 'Meu exercício');
    expect(archived.rankFactor, isNull);
  });

  test('exercise validation rejects empty names', () {
    expect(
      () => ExerciseRepository(db).create(
        const ExerciseDraft(
          name: '   ',
          primaryMuscle: Muscle.core,
          equipment: Equipment.other,
          kind: ExerciseKind.duration,
        ),
      ),
      throwsArgumentError,
    );
  });

  test('body weight keeps one entry per day', () async {
    final repo = BodyWeightRepository(db);
    await repo.log(DateTime(2026, 10, 20, 8), 80);
    await repo.log(DateTime(2026, 10, 20, 20), 81);
    await repo.log(DateTime(2026, 10, 21), 80.5);
    final all = await repo.watchAll().first;
    expect(all.map((e) => e.weightKg), [80.5, 81]);
    expect(() => repo.log(DateTime.now(), 5), throwsArgumentError);
  });

  test('profile survives a round-trip and tolerates garbage', () async {
    final settings = SettingsRepository(db);
    expect((await settings.readProfile()).onboarded, isFalse);
    await settings.saveProfile(
      const Profile(
        name: 'Ana',
        sex: Sex.female,
        weeklyGoal: 4,
        onboarded: true,
      ),
    );
    final p = await settings.readProfile();
    expect(p.name, 'Ana');
    expect(p.sex, Sex.female);
    expect(p.weeklyGoal, 4);
    expect(p.onboarded, isTrue);

    await settings.write(SettingsRepository.profileKey, '{not json');
    expect((await settings.readProfile()).name, '');
    expect(
      Profile.fromJson({'sex': 'alien', 'weeklyGoal': 'x'}).sex,
      Sex.unspecified,
    );
  });

  test('backup export and import restore the same data', () async {
    final exId = (await db.select(db.exercises).get()).first.id;
    await WorkoutRepository(db).insert(
      WorkoutRecord(
        id: -1,
        name: 'Backup',
        startedAt: DateTime(2026, 5, 5, 10),
        endedAt: DateTime(2026, 5, 5, 11),
        exercises: [
          ExerciseEntry(
            exerciseId: exId,
            sets: const [
              SetEntry(type: SetType.normal, weightKg: 77.5, reps: 3),
            ],
          ),
        ],
      ),
    );
    await BodyWeightRepository(db).log(DateTime(2026, 5, 5), 82);
    await SettingsRepository(
      db,
    ).saveProfile(const Profile(name: 'Rui', onboarded: true));
    await SettingsRepository(
      db,
    ).write(SettingsRepository.activeWorkoutKey, '{}');

    final backup = BackupRepository(db);
    final json = await backup.export();
    expect(json, isNot(contains(SettingsRepository.activeWorkoutKey)));

    final other = memoryDatabase();
    addTearDown(other.close);
    await BackupRepository(other).import(json);

    final restored = await WorkoutRepository(other).loadHistory();
    expect(restored.single.name, 'Backup');
    expect(restored.single.startedAt, DateTime(2026, 5, 5, 10));
    expect(restored.single.exercises.single.sets.single.weightKg, 77.5);
    expect((await SettingsRepository(other).readProfile()).name, 'Rui');
    expect(
      (await BodyWeightRepository(other).watchAll().first).single.weightKg,
      82,
    );
  });

  test('import rejects foreign files and unknown columns', () async {
    final backup = BackupRepository(db);
    await expectLater(
      backup.import('nope'),
      throwsA(isA<BackupFormatException>()),
    );
    await expectLater(
      backup.import('{"format":"other"}'),
      throwsA(isA<BackupFormatException>()),
    );

    await backup.import(
      '{"format":"apice-backup","version":1,"tables":{'
      '"key_values":[{"key":"k","value":"v","evil\\"; DROP TABLE workouts; --":1}]}}',
    );
    expect(await SettingsRepository(db).read('k'), 'v');
    expect(await db.select(db.workouts).get(), isEmpty);
  });

  test('wipe restores the built-in library', () async {
    await ExerciseRepository(db).create(
      const ExerciseDraft(
        name: 'X',
        primaryMuscle: Muscle.core,
        equipment: Equipment.other,
        kind: ExerciseKind.duration,
      ),
    );
    await BackupRepository(db).wipe();
    expect(await db.select(db.exercises).get(), hasLength(librarySeed.length));
    expect(await db.select(db.routines).get(), isNotEmpty);
  });
}
