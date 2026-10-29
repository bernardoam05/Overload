import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:overload/app/providers.dart';
import 'package:overload/data/database.dart';
import 'package:overload/data/repositories/settings_repository.dart';
import 'package:overload/domain/enums.dart';
import 'package:overload/domain/models.dart';
import 'package:overload/domain/records.dart';
import 'package:overload/features/workout/active_workout.dart';
import 'package:overload/features/workout/active_workout_controller.dart';

import '../helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProviderContainer container;

  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  setUp(() async {
    db = memoryDatabase();
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    for (final p in [
      exercisesProvider,
      historyProvider,
      bodyWeightsProvider,
      profileProvider,
    ]) {
      container.listen(p, (_, _) {});
    }
    await container.read(exercisesProvider.future);
    await container.read(historyProvider.future);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  ActiveWorkoutController controller() =>
      container.read(activeWorkoutProvider.notifier);
  ActiveWorkout state() => container.read(activeWorkoutProvider)!;

  Future<int> benchId() async => (await db.select(db.exercises).get())
      .firstWhere((e) => e.seedKey == 'bench')
      .id;

  test('logging sets and finishing stores the workout', () async {
    final bench = await benchId();
    controller()
      ..startEmpty()
      ..addExercises([bench]);
    final ex = state().exercises.single;
    final set = ex.sets.single;
    controller()
      ..setWeight(ex.id, set.id, 100)
      ..setReps(ex.id, set.id, 5)
      ..addSet(ex.id); // copies 100 × 5, left incomplete
    expect(state().exercises.single.sets.last.weightKg, 100);
    expect(
      controller().toggleDone(
        ex.id,
        set.id,
        weightRequired: true,
        restSeconds: 90,
      ),
      isTrue,
    );
    expect(state().restEndsAt, isNotNull);

    final summary = await controller().finish();
    await settle();

    expect(container.read(activeWorkoutProvider), isNull);
    expect(summary.record.setCount, 1, reason: 'incomplete sets are discarded');
    expect(summary.xp, greaterThan(0));
    expect(summary.rankChanges.map((c) => c.group), contains(RankGroup.chest));
    final history = await container.read(historyProvider.future);
    expect(history.single.exercises.single.sets.single.weightKg, 100);
    expect(history.single.xp, summary.xp);
  });

  test('ticking an empty set uses the previous performance', () async {
    final bench = await benchId();
    controller()
      ..startEmpty()
      ..addExercises([bench]);
    final ex = state().exercises.single;
    final ok = controller().toggleDone(
      ex.id,
      ex.sets.single.id,
      hint: const SetEntry(type: SetType.normal, weightKg: 70, reps: 8),
      weightRequired: true,
    );
    expect(ok, isTrue);
    final s = state().exercises.single.sets.single;
    expect((s.weightKg, s.reps, s.done), (70.0, 8, true));
  });

  test('a set without values and without hint cannot be completed', () async {
    final bench = await benchId();
    controller()
      ..startEmpty()
      ..addExercises([bench]);
    final ex = state().exercises.single;
    expect(
      controller().toggleDone(ex.id, ex.sets.single.id, weightRequired: true),
      isFalse,
    );
    expect(state().exercises.single.sets.single.done, isFalse);
  });

  test('finishing without completed sets fails', () async {
    controller().startEmpty();
    await expectLater(controller().finish(), throwsA(isA<FinishException>()));
    expect(container.read(activeWorkoutProvider), isNotNull);
  });

  test('second workout detects personal records', () async {
    final bench = await benchId();
    Future<WorkoutSummary> logBench(double kg) async {
      controller()
        ..startEmpty()
        ..addExercises([bench]);
      final ex = state().exercises.single;
      controller()
        ..setWeight(ex.id, ex.sets.single.id, kg)
        ..setReps(ex.id, ex.sets.single.id, 5)
        ..toggleDone(ex.id, ex.sets.single.id, weightRequired: true);
      final s = await controller().finish();
      await settle();
      return s;
    }

    expect((await logBench(80)).records, isEmpty);
    final second = await logBench(85);
    expect(
      second.records.map((r) => r.type),
      containsAll([RecordType.weight, RecordType.e1rm]),
    );
  });

  test('editing replaces the original workout', () async {
    final bench = await benchId();
    controller()
      ..startEmpty()
      ..addExercises([bench]);
    final ex = state().exercises.single;
    controller()
      ..setWeight(ex.id, ex.sets.single.id, 60)
      ..setReps(ex.id, ex.sets.single.id, 10)
      ..toggleDone(ex.id, ex.sets.single.id, weightRequired: true);
    await controller().finish();
    await settle();

    final original = (await container.read(historyProvider.future)).single;
    controller().edit(original);
    expect(state().isEditing, isTrue);
    final e = state().exercises.single;
    controller().setWeight(e.id, e.sets.single.id, 65);
    final summary = await controller().finish();
    await settle();

    expect(summary.edited, isTrue);
    final history = await container.read(historyProvider.future);
    expect(history, hasLength(1));
    expect(history.single.id, original.id);
    expect(history.single.exercises.single.sets.single.weightKg, 65);
    expect(history.single.startedAt, original.startedAt);
  });

  test('draft is persisted and can be decoded', () async {
    final bench = await benchId();
    controller()
      ..startEmpty()
      ..addExercises([bench]);
    controller().flushDraft();
    await settle();
    final raw = await SettingsRepository(
      db,
    ).read(SettingsRepository.activeWorkoutKey);
    final restored = ActiveWorkout.fromJson(
      jsonDecode(raw!) as Map<String, Object?>,
    );
    expect(restored.exercises.single.exerciseId, bench);

    controller().discard();
    await settle();
    expect(
      await SettingsRepository(db).read(SettingsRepository.activeWorkoutKey),
      isNull,
    );
  });

  test('rest timer can be adjusted and skipped', () {
    controller()
      ..startEmpty()
      ..startRest(60);
    final end = state().restEndsAt!;
    controller().adjustRest(15);
    expect(state().restEndsAt!.difference(end).inSeconds, 15);
    controller().adjustRest(-600);
    expect(state().restEndsAt, isNull);
    controller()
      ..startRest(30)
      ..skipRest();
    expect(state().restEndsAt, isNull);
  });

  test('removed exercises and sets can be restored in place', () async {
    final ids = (await db.select(db.exercises).get())
        .take(3)
        .map((e) => e.id)
        .toList();
    controller()
      ..startEmpty()
      ..addExercises(ids);
    final middle = state().exercises[1];
    final removed = controller().removeExercise(middle.id)!;
    expect(state().exercises.map((e) => e.exerciseId), [ids[0], ids[2]]);
    controller().restoreExercise(removed.$1, removed.$2);
    expect(state().exercises.map((e) => e.exerciseId), ids);

    final ex = state().exercises.first;
    controller().addSet(ex.id);
    final first = state().exercises.first.sets.first;
    final r = controller().removeSet(ex.id, first.id)!;
    expect(state().exercises.first.sets, hasLength(1));
    controller().restoreSet(ex.id, r.$1, r.$2);
    expect(state().exercises.first.sets.first.id, first.id);
  });

  group('rest after a set', () {
    ActiveWorkout workout(List<ActiveSet> sets) => ActiveWorkout(
      name: 'T',
      startedAt: DateTime(2026),
      exercises: [ActiveExercise(id: 'e', exerciseId: 1, sets: sets)],
    );

    test('no rest before a drop set, full rest after it', () {
      final w = workout(const [
        ActiveSet(id: 'a', done: true),
        ActiveSet(id: 'b', type: SetType.drop),
        ActiveSet(id: 'c'),
      ]);
      expect(restAfter(w, 'e', 'a', 90), isNull);
      final afterDrop = workout(const [
        ActiveSet(id: 'a', done: true),
        ActiveSet(id: 'b', type: SetType.drop, done: true),
        ActiveSet(id: 'c'),
      ]);
      expect(restAfter(afterDrop, 'e', 'b', 90), 90);
    });

    test('warm-ups get a shorter rest', () {
      final w = workout(const [
        ActiveSet(id: 'a', type: SetType.warmup, done: true),
        ActiveSet(id: 'b'),
      ]);
      expect(restAfter(w, 'e', 'a', 120), 60);
      expect(restAfter(w, 'e', 'a', 60), 30);
    });

    test('no rest after the last set of the workout', () {
      final w = workout(const [
        ActiveSet(id: 'a', done: true),
        ActiveSet(id: 'b', done: true),
      ]);
      expect(restAfter(w, 'e', 'b', 90), isNull);
    });
  });

  test('filled but unticked sets can be completed in one go', () async {
    final bench = await benchId();
    controller()
      ..startEmpty()
      ..addExercises([bench]);
    final ex = state().exercises.single;
    controller()
      ..setWeight(ex.id, ex.sets.single.id, 80)
      ..setReps(ex.id, ex.sets.single.id, 5)
      ..addSet(ex.id)
      ..addSet(ex.id);
    final empty = state().exercises.single.sets.last;
    controller()
      ..setWeight(ex.id, empty.id, null)
      ..setReps(ex.id, empty.id, null);
    expect(controller().completeFilledSets(const {}), 2);
    expect(state().exercises.single.sets.map((s) => s.done), [
      true,
      true,
      false,
    ]);
  });

  test('assisted sets use body weight minus the assistance', () {
    const set = SetEntry(type: SetType.normal, weightKg: 30, reps: 1);
    expect(set.e1rm(ExerciseKind.assisted, 80), 50);
  });
}
