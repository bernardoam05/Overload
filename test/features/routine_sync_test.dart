import 'package:flutter_test/flutter_test.dart';
import 'package:overload/data/database.dart';
import 'package:overload/data/repositories/routine_repository.dart';
import 'package:overload/domain/enums.dart';
import 'package:overload/features/workout/active_workout.dart';
import 'package:overload/features/workout/routine_sync.dart';

import '../helpers.dart';

const _n = SetType.normal;
const _a = SetType.warmup;
const _d = SetType.drop;

RoutineWithItems _routine(List<RoutineItem> items) => RoutineWithItems(
  Routine(
    id: 7,
    name: 'Push',
    notes: '',
    position: 0,
    createdAt: DateTime(2026),
  ),
  items,
);

ActiveExercise _ex(
  String id,
  int exerciseId,
  List<SetType> types, {
  int? routineIndex,
  String routineNotes = '',
}) => ActiveExercise(
  id: id,
  exerciseId: exerciseId,
  routineIndex: routineIndex,
  routineNotes: routineNotes,
  sets: [
    for (final (i, t) in types.indexed)
      ActiveSet(id: '$id-$i', type: t, weightKg: 20, reps: 10),
  ],
);

ActiveWorkout _workout(List<ActiveExercise> exercises) => ActiveWorkout(
  name: 'Push',
  startedAt: DateTime(2026, 11, 3),
  routineId: 7,
  exercises: exercises,
);

final _library = {
  for (final id in [1, 2, 3, 4]) id: exercise(id, name: 'E$id'),
};

void main() {
  final routine = _routine([
    RoutineItem(exerciseId: 1, sets: 3, reps: 6),
    RoutineItem(exerciseId: 2, sets: 3, reps: 12, notes: 'banco a 30°'),
    RoutineItem(exerciseId: 3, sets: 2),
  ]);

  test('no changes, nothing to ask', () {
    final w = _workout([
      _ex('a', 1, [_n, _n, _n], routineIndex: 0),
      _ex('b', 2, [_n, _n, _n], routineIndex: 1, routineNotes: 'banco a 30°'),
      _ex('c', 3, [_n, _n], routineIndex: 2),
    ]);
    expect(routineSync(w, routine, _library), isNull);
  });

  test('a warm-up, a drop and a pinned note are proposed and applied', () {
    final w = _workout([
      _ex('a', 1, [_a, _n, _n, _n, _d], routineIndex: 0, routineNotes: 'pausa'),
      _ex('b', 2, [_n, _n, _n], routineIndex: 1, routineNotes: 'banco a 30°'),
      _ex('c', 3, [_n, _n], routineIndex: 2),
    ]);
    final sync = routineSync(w, routine, _library)!;
    expect(sync.defaultSelection, {'sets:0', 'notes:0'});
    final items = sync.apply(sync.defaultSelection);
    expect(items.map((i) => i.exerciseId), [1, 2, 3]);
    expect(items[0].setTypes, [_a, _n, _n, _n, _d]);
    expect(items[0].reps, 6, reason: 'targets are kept');
    expect(items[0].notes, 'pausa');
    expect(items[1].notes, 'banco a 30°');
  });

  test('removed sets and exercises are listed but not selected', () {
    final w = _workout([
      _ex('a', 1, [_n, _n], routineIndex: 0),
      _ex('b', 2, [_n, _n, _n], routineIndex: 1, routineNotes: 'banco a 30°'),
    ]);
    final sync = routineSync(w, routine, _library)!;
    expect(sync.changes.map((c) => c.id), ['sets:0', 'removed:2']);
    expect(sync.defaultSelection, isEmpty);
    expect(sync.apply({}).map((i) => (i.exerciseId, i.sets)), [
      (1, 3),
      (2, 3),
      (3, 2),
    ]);
    expect(
      sync.apply({'sets:0', 'removed:2'}).map((i) => (i.exerciseId, i.sets)),
      [(1, 2), (2, 3)],
    );
  });

  test(
    'added exercises keep their place; replacements and order are opt-in',
    () {
      final w = _workout([
        _ex('b', 2, [_n, _n, _n], routineIndex: 1, routineNotes: 'banco a 30°'),
        _ex('a', 4, [_n, _n, _n], routineIndex: 0),
        _ex('new', 1, [_n, _n]),
        _ex('c', 3, [_n, _n], routineIndex: 2),
      ]);
      final sync = routineSync(w, routine, _library)!;
      expect(sync.changes.map((c) => c.id), [
        'replaced:0',
        'added:new',
        'order',
      ]);
      expect(sync.defaultSelection, {'added:new'});

      // Routine order kept, the new exercise goes after the one it followed.
      expect(sync.apply({'added:new'}).map((i) => i.exerciseId), [1, 1, 2, 3]);
      expect(
        sync
            .apply({'added:new', 'replaced:0', 'order'})
            .map((i) => i.exerciseId),
        [2, 4, 1, 3],
      );
    },
  );

  test('workouts without routine links are matched by exercise', () {
    final match = matchToRoutine([
      _ex('x', 2, [_n]),
      _ex('y', 1, [_n]),
      _ex('z', 2, [_n]),
    ], routine.items);
    expect(match, [1, 0, null]);
  });

  test('describes set plans', () {
    expect(
      describeSetTypes([_a, _a, _n, _n, _n, _d]),
      '2 aquecimentos + 3 séries + 1 drop',
    );
    expect(describeSetTypes([_n]), '1 série');
  });
}
