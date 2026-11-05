import 'package:flutter_test/flutter_test.dart';
import 'package:overload/domain/enums.dart';
import 'package:overload/domain/superset.dart';
import 'package:overload/features/workout/active_workout.dart';
import 'package:overload/features/workout/active_workout_controller.dart';

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
}
