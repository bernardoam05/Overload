import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:overload/app/providers.dart';
import 'package:overload/data/database.dart';
import 'package:overload/data/repositories/routine_repository.dart';
import 'package:overload/data/repositories/settings_repository.dart';
import 'package:overload/domain/enums.dart';
import 'package:overload/domain/exercise.dart';
import 'package:overload/features/train/routine_editor_screen.dart';
import 'package:overload/features/workout/active_workout.dart';
import 'package:overload/features/workout/active_workout_controller.dart';
import 'package:overload/features/workout/exercise_card.dart';
import 'package:overload/features/workout/finish_sheet.dart';
import 'package:overload/features/workout/routine_sync.dart';

import '../helpers.dart';

const _curl = Exercise(
  id: 1,
  name: 'Curl com halteres',
  primaryMuscle: Muscle.biceps,
  secondaryMuscles: [],
  equipment: Equipment.dumbbell,
  kind: ExerciseKind.weighted,
  rankFactor: 2.1,
  instructions: '',
  isCustom: false,
  seedKey: 'db_curl',
  restSeconds: null,
  archived: false,
  loadMode: LoadMode.perHand,
);

final _routine = RoutineWithItems(
  Routine(
    id: 3,
    name: 'Braços',
    notes: '',
    position: 0,
    createdAt: DateTime(2026),
  ),
  [
    RoutineItem(
      exerciseId: 1,
      setTypes: const [SetType.warmup, SetType.normal, SetType.drop],
      reps: 12,
      notes: 'cotovelos parados',
    ),
  ],
);

void main() {
  late AppDatabase db;

  setUp(() async {
    await initializeDateFormatting('pt_PT');
    db = memoryDatabase();
  });
  tearDown(() => db.close());

  Future<void> pumpPhone(
    WidgetTester tester,
    Widget child, {
    ActiveWorkout? workout,
  }) async {
    tester.view.physicalSize = const Size(360 * 3, 740 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    const profile = Profile(
      name: 'Teste',
      onboarded: true,
      seenWorkoutTips: true,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          initialProfileProvider.overrideWithValue(profile),
          profileProvider.overrideWith((ref) => Stream.value(profile)),
          exercisesProvider.overrideWith((ref) => Stream.value(const [_curl])),
          historyProvider.overrideWith((ref) => Stream.value(const [])),
          routinesProvider.overrideWith((ref) => Stream.value([_routine])),
          bodyWeightsProvider.overrideWith((ref) => Stream.value(const [])),
          initialActiveWorkoutProvider.overrideWithValue(workout),
        ],
        child: MaterialApp(home: Scaffold(body: child)),
      ),
    );
    await tester.pumpAndSettle();
  }

  ActiveWorkout fromRoutine() => ActiveWorkout(
    name: 'Braços',
    startedAt: DateTime(2026, 11, 3, 18),
    routineId: 3,
    exercises: [
      ActiveExercise(
        id: 'e1',
        exerciseId: 1,
        routineIndex: 0,
        routineNotes: 'cotovelos parados',
        sets: [
          for (final (i, t) in _routine.items.single.setTypes.indexed)
            ActiveSet(id: 's$i', type: t),
        ],
      ),
    ],
  );

  testWidgets('the workout card shows the plan, pinned note and load mode', (
    tester,
  ) async {
    await pumpPhone(
      tester,
      ListView(
        children: const [ActiveExerciseCard(entryId: 'e1', index: 0, total: 1)],
      ),
      workout: fromRoutine(),
    );
    expect(find.text('cotovelos parados'), findsOneWidget);
    expect(find.text('Um haltere em cada mão · peso de cada'), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
    expect(find.text('D'), findsOneWidget);

    await tester.tap(find.text('+ Aquecimento'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('A'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the routine editor edits set types', (tester) async {
    await pumpPhone(
      tester,
      RoutineEditorScreen(template: RoutineTemplate('Braços', _routine.items)),
    );
    expect(find.text('1 aquecimento + 1 série + 1 drop'), findsOneWidget);
    await tester.tap(find.text('+ Série'));
    await tester.pump();
    await tester.tap(find.text('+ Aquecimento'));
    await tester.pump();
    expect(find.text('2 aquecimentos + 2 séries + 1 drop'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('finishing lists the changes to take to the routine', (
    tester,
  ) async {
    final base = fromRoutine();
    final w = base.copyWith(
      exercises: [
        base.exercises.single.copyWith(
          routineNotes: 'cotovelos parados, subir em 2 s',
          sets: [
            ...base.exercises.single.sets,
            const ActiveSet(id: 'x', type: SetType.drop, done: true),
          ],
        ),
      ],
    );
    final sync = routineSync(w, _routine, {1: _curl})!;
    FinishResult? result;
    await pumpPhone(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await showFinishSheet(
            context,
            workout: w,
            library: {1: _curl},
            unit: WeightUnit.kg,
            sync: sync,
          ),
          child: const Text('abrir'),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.text('Levar para a rotina «Braços»?'), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNWidgets(2));

    // Untick the note: only the extra drop goes to the routine.
    await tester.tap(find.text('Curl com halteres: nota fixa'));
    await tester.pump();
    await tester.tap(find.text('Terminar treino'));
    await tester.pumpAndSettle();
    expect(result?.routineChanges, {'sets:0'});
    expect(tester.takeException(), isNull);
  });
}
