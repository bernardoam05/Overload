import 'package:flutter_test/flutter_test.dart';
import 'package:overload/domain/progression.dart';
import 'package:overload/domain/reminders.dart';
import 'package:overload/features/notifications/notification_sync.dart';
import 'package:overload/features/workout/active_workout.dart';

import '../helpers.dart';

StreakInfo _streak({
  required int goal,
  required List<DateTime> days,
  required DateTime now,
}) => computeStreak(
  [for (final (i, d) in days.indexed) workout(i, d, {})],
  weeklyGoal: goal,
  now: now,
);

void main() {
  group('streak reminder', () {
    // Wednesday 22 October 2026.
    final wednesday = DateTime(2026, 10, 22, 9);

    test('fires at 18h on the last day the goal can still be met', () {
      final s = _streak(
        goal: 3,
        days: [DateTime(2026, 10, 20)],
        now: wednesday,
      );
      final r = planStreakReminder(s, now: wednesday)!;
      // Needs 2 more: Saturday and Sunday are the last chance.
      expect(r.at, DateTime(2026, 10, 24, 18));
      expect(r.body, contains('Faltam 2 treinos'));
    });

    test('no reminder once the goal is met', () {
      final s = _streak(
        goal: 1,
        days: [DateTime(2026, 10, 20)],
        now: wednesday,
      );
      expect(planStreakReminder(s, now: wednesday), isNull);
    });

    test('no reminder when the last chance already passed', () {
      final sunday = DateTime(2026, 10, 25, 20);
      final s = _streak(goal: 3, days: [DateTime(2026, 10, 20)], now: sunday);
      expect(planStreakReminder(s, now: sunday), isNull);
    });

    test('mentions the streak at stake', () {
      final s = _streak(
        goal: 1,
        days: [DateTime(2026, 10, 6), DateTime(2026, 10, 13)],
        now: wednesday,
      );
      final r = planStreakReminder(s, now: wednesday)!;
      expect(r.title, contains('2 semanas'));
      expect(r.at, DateTime(2026, 10, 25, 18));
    });
  });

  test('unfinished workout reminder waits at least 3 hours from the start', () {
    final start = DateTime(2026, 10, 22, 18);
    final early = planUnfinishedWorkoutReminder(
      name: 'Push',
      startedAt: start,
      now: start,
    );
    expect(early.at, DateTime(2026, 10, 22, 21));
    expect(early.requiresWorkout, isTrue);

    final late = planUnfinishedWorkoutReminder(
      name: 'Push',
      startedAt: start,
      now: DateTime(2026, 10, 22, 21, 30),
    );
    expect(late.at, DateTime(2026, 10, 22, 23));
  });

  test('live notification shows progress and the next set', () {
    final w = ActiveWorkout(
      name: 'Push',
      startedAt: DateTime(2026, 10, 22, 18),
      exercises: [
        const ActiveExercise(
          id: 'a',
          exerciseId: 1,
          sets: [
            ActiveSet(id: '1', weightKg: 80, reps: 5, done: true),
            ActiveSet(id: '2', weightKg: 80, reps: 5),
          ],
        ),
        const ActiveExercise(
          id: 'b',
          exerciseId: 2,
          sets: [ActiveSet(id: '3')],
        ),
      ],
    );
    final notice = workoutNotice(
      w,
      {1: exercise(1, name: 'Supino reto'), 2: exercise(2)},
      restAlerts: true,
      showOngoing: true,
    );
    expect(notice.setsDone, 1);
    expect(notice.setsTotal, 3);
    expect(notice.segments, [2, 1]);
    expect(notice.nextLabel, 'Supino reto · série 2 de 2');
    expect(notice.toMap()['restEndsAt'], 0);
  });
}
