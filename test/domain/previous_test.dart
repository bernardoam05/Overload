import 'package:flutter_test/flutter_test.dart';
import 'package:overload/domain/enums.dart';
import 'package:overload/domain/models.dart';
import 'package:overload/domain/previous.dart';

import '../helpers.dart';

WorkoutRecord _w(int id, DateTime at, List<SetEntry> sets, {int? routineId}) =>
    WorkoutRecord(
      id: id,
      name: 'W$id',
      startedAt: at,
      endedAt: at.add(const Duration(hours: 1)),
      routineId: routineId,
      exercises: [ExerciseEntry(exerciseId: 1, sets: sets)],
    );

const _s = SetType.normal;

void main() {
  final now = DateTime(2026, 10, 22);

  test('prefers the latest session of the same routine', () {
    final history = [
      _w(3, DateTime(2026, 10, 20), const [
        SetEntry(type: _s, weightKg: 60, reps: 12),
      ], routineId: 2),
      _w(2, DateTime(2026, 10, 17), const [
        SetEntry(type: _s, weightKg: 100, reps: 5),
      ], routineId: 1),
      _w(1, DateTime(2026, 10, 10), const [
        SetEntry(type: _s, weightKg: 95, reps: 5),
      ], routineId: 1),
    ];
    expect(
      previousPerformances(history, routineId: 1, now: now)[1]!.workout.id,
      2,
    );
    expect(previousPerformances(history, now: now)[1]!.workout.id, 3);
  });

  test('ignores an old same-routine session in favour of a recent one', () {
    final history = [
      _w(2, DateTime(2026, 10, 20), const [
        SetEntry(type: _s, weightKg: 60, reps: 12),
      ]),
      _w(1, DateTime(2026, 6, 1), const [
        SetEntry(type: _s, weightKg: 100, reps: 5),
      ], routineId: 1),
    ];
    expect(
      previousPerformances(history, routineId: 1, now: now)[1]!.workout.id,
      2,
    );
  });

  test('skips the workout being edited', () {
    final history = [
      _w(2, DateTime(2026, 10, 20), const [
        SetEntry(type: _s, weightKg: 60, reps: 12),
      ]),
      _w(1, DateTime(2026, 10, 10), const [
        SetEntry(type: _s, weightKg: 50, reps: 12),
      ]),
    ];
    expect(
      previousPerformances(
        history,
        excludeWorkoutId: 2,
        now: now,
      )[1]!.workout.id,
      1,
    );
  });

  test('warm-ups and working sets are matched separately', () {
    final p = PreviousPerformance(
      _w(1, now, const []),
      const ExerciseEntry(
        exerciseId: 1,
        sets: [
          SetEntry(type: SetType.warmup, weightKg: 40, reps: 10),
          SetEntry(type: _s, weightKg: 80, reps: 6),
          SetEntry(type: _s, weightKg: 80, reps: 5),
        ],
      ),
    );
    expect(p.match(SetType.warmup, 0, 0)!.weightKg, 40);
    // Today without a warm-up: the first set still compares to 80 × 6.
    expect(p.match(_s, 0, 0)!.reps, 6);
    expect(p.match(SetType.failure, 0, 1)!.reps, 5);
    expect(p.match(_s, 0, 2), isNull);
  });

  group('compareSets', () {
    final kind = exercise(1).kind;
    SetEntry s(double kg, int reps) =>
        SetEntry(type: _s, weightKg: kg, reps: reps);

    test('more weight or reps is better', () {
      expect(compareSets(s(82.5, 6), s(80, 6), kind, 80), 1);
      expect(compareSets(s(80, 7), s(80, 6), kind, 80), 1);
      expect(compareSets(s(80, 6), s(80, 6), kind, 80), 0);
      expect(compareSets(s(75, 6), s(80, 6), kind, 80), -1);
    });

    test('reps beyond the estimate cap still count as progress', () {
      expect(compareSets(s(40, 20), s(40, 18), kind, 80), 1);
    });

    test('body-weight sets compare reps with body weight included', () {
      expect(compareSets(s(0, 10), s(0, 8), ExerciseKind.bodyweight, 80), 1);
      expect(compareSets(s(10, 8), s(0, 8), ExerciseKind.bodyweight, 80), 1);
    });

    test('timed sets compare seconds', () {
      expect(compareSets(s(0, 60), s(0, 45), ExerciseKind.duration, 80), 1);
      expect(compareSets(s(0, 30), s(0, 45), ExerciseKind.duration, 80), -1);
    });
  });
}
