import 'package:flutter_test/flutter_test.dart';
import 'package:overload/domain/enums.dart';
import 'package:overload/domain/superset.dart';
import 'package:overload/features/workout/active_workout.dart';
import 'package:overload/features/workout/active_workout_controller.dart';
import 'package:overload/features/workout/exercise_card_extras.dart';

ActiveExercise _ex(String id, {bool link = false, bool done = false}) =>
    ActiveExercise(
      id: id,
      exerciseId: 1,
      supersetNext: link,
      sets: [
        ActiveSet(id: '$id-1', reps: 10, weightKg: 20, done: done),
        ActiveSet(id: '$id-2'),
      ],
    );

ActiveWorkout _w(List<ActiveExercise> e) =>
    ActiveWorkout(name: 'T', startedAt: DateTime(2026), exercises: e);

void main() {
  test('groups consecutive linked exercises', () {
    expect(supersetGroups([true, false, false, true, true, false]), [
      0,
      0,
      null,
      1,
      1,
      1,
    ]);
  });

  test('a link on the last exercise is ignored', () {
    expect(supersetGroups([false, true]), [null, null]);
    expect(supersetGroups([true]), [null]);
  });

  test('letters', () {
    expect(supersetLetter(0), 'A');
    expect(supersetLetter(2), 'C');
  });

  group('rest inside a superset', () {
    test('no rest when handing over to the next exercise', () {
      final w = _w([_ex('a', link: true, done: true), _ex('b')]);
      expect(restAfter(w, 'a', 'a-1', 90), isNull);
    });

    test('normal rest after the last exercise of the superset', () {
      final w = _w([_ex('a', link: true), _ex('b', done: true)]);
      expect(restAfter(w, 'b', 'b-1', 90), 90);
    });

    test('normal rest when the next exercise has nothing left', () {
      final finished = ActiveExercise(
        id: 'b',
        exerciseId: 1,
        sets: const [ActiveSet(id: 'b-1', reps: 8, weightKg: 10, done: true)],
      );
      final w = _w([_ex('a', link: true, done: true), finished]);
      expect(restAfter(w, 'a', 'a-1', 90), 90);
    });

    test('warm-ups keep their short rest', () {
      final w = _w([
        ActiveExercise(
          id: 'a',
          exerciseId: 1,
          supersetNext: true,
          sets: const [
            ActiveSet(id: 'a-1', type: SetType.warmup, done: true),
            ActiveSet(id: 'a-2'),
          ],
        ),
        _ex('b'),
      ]);
      expect(restAfter(w, 'a', 'a-1', 90), 45);
    });
  });

  group('tips show on the current exercise', () {
    ActiveExercise full(String id, {bool link = false}) => ActiveExercise(
      id: id,
      exerciseId: 1,
      supersetNext: link,
      sets: [ActiveSet(id: '$id-1', reps: 10, weightKg: 20, done: true)],
    );
    List<bool> current(ActiveWorkout w) => [
      for (var i = 0; i < w.exercises.length; i++) isCurrentExercise(w, i),
    ];

    test('first exercise, and the next once the previous is complete', () {
      expect(current(_w([_ex('a'), _ex('b'), _ex('c')])), [true, false, false]);
      expect(current(_w([full('a'), _ex('b'), _ex('c')])), [true, true, false]);
      // Started but not complete: the next one waits.
      expect(current(_w([_ex('a', done: true), _ex('b'), _ex('c')])), [
        true,
        false,
        false,
      ]);
      // Started out of order: shows on that one too.
      expect(current(_w([_ex('a'), _ex('b'), _ex('c', done: true)])), [
        true,
        false,
        true,
      ]);
    });

    test('a superset shows all its exercises at once', () {
      expect(current(_w([_ex('a', link: true), _ex('b'), _ex('c')])), [
        true,
        true,
        false,
      ]);
      expect(
        current(_w([_ex('a'), _ex('b', link: true), _ex('c'), _ex('d')])),
        [true, false, false, false],
      );
      expect(
        current(_w([full('a'), _ex('b', link: true), _ex('c'), _ex('d')])),
        [true, true, true, false],
      );
      // After a superset: only when every exercise of it is complete.
      expect(
        current(_w([full('a', link: true), _ex('b', done: true), _ex('c')])),
        [true, true, false],
      );
      expect(current(_w([full('a', link: true), full('b'), _ex('c')])), [
        true,
        true,
        true,
      ]);
    });
  });
}
