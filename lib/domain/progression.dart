import 'dart:math' as math;

import 'models.dart';

/// XP awarded for finishing a workout.
int workoutXp({
  required int workingSets,
  required Duration duration,
  required int personalRecords,
}) {
  if (workingSets == 0) return 0;
  final sets = workingSets > 40 ? 40 : workingSets;
  final minutes = duration.inMinutes > 90 ? 90 : duration.inMinutes;
  return 40 + 4 * sets + minutes + 30 * personalRecords;
}

int xpToNextLevel(int level) => 100 + 25 * (level - 1);

class LevelInfo {
  const LevelInfo(this.level, this.xpIntoLevel, this.xpForLevel, this.totalXp);
  final int level;
  final int xpIntoLevel;
  final int xpForLevel;
  final int totalXp;

  double get progress => xpForLevel == 0 ? 0 : xpIntoLevel / xpForLevel;
}

LevelInfo levelForXp(int totalXp) {
  var level = 1;
  var remaining = totalXp;
  while (remaining >= xpToNextLevel(level)) {
    remaining -= xpToNextLevel(level);
    level++;
  }
  return LevelInfo(level, remaining, xpToNextLevel(level), totalXp);
}

DateTime dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

/// Monday of the week containing [t].
DateTime weekStart(DateTime t) {
  return DateTime(t.year, t.month, t.day - (t.weekday - DateTime.monday));
}

class StreakInfo {
  const StreakInfo({
    required this.current,
    required this.best,
    required this.daysThisWeek,
    required this.goal,
    required this.trainedDays,
  });

  /// Consecutive weeks (ending now) in which the weekly goal was met. The
  /// ongoing week only adds to the streak once its goal is met, and never
  /// breaks it while it is still in progress.
  final int current;
  final int best;
  final int daysThisWeek;
  final int goal;
  final Set<DateTime> trainedDays;

  bool get goalMetThisWeek => daysThisWeek >= goal;
}

StreakInfo computeStreak(
  Iterable<WorkoutRecord> history, {
  required int weeklyGoal,
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  final days = {for (final w in history) dayOf(w.startedAt)};
  final perWeek = <DateTime, int>{};
  for (final d in days) {
    final w = weekStart(d);
    perWeek[w] = (perWeek[w] ?? 0) + 1;
  }
  final goal = math.max(1, weeklyGoal);
  bool met(DateTime week) => (perWeek[week] ?? 0) >= goal;

  final thisWeek = weekStart(today);
  var current = met(thisWeek) ? 1 : 0;
  var week = _previousWeek(thisWeek);
  while (met(week)) {
    current++;
    week = _previousWeek(week);
  }

  var best = 0;
  if (perWeek.isNotEmpty) {
    final weeks = perWeek.keys.toList()..sort();
    var run = 0;
    DateTime? prev;
    for (final w in weeks) {
      if (!met(w)) {
        run = 0;
      } else {
        final contiguous = prev != null && _previousWeek(w) == prev;
        run = contiguous ? run + 1 : 1;
        prev = w;
      }
      best = math.max(best, run);
    }
  }

  return StreakInfo(
    current: current,
    best: math.max(best, current),
    daysThisWeek: perWeek[thisWeek] ?? 0,
    goal: goal,
    trainedDays: days,
  );
}

/// Calendar arithmetic that is safe across daylight-saving changes.
DateTime _previousWeek(DateTime monday) =>
    DateTime(monday.year, monday.month, monday.day - 7);
