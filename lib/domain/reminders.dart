import 'progression.dart';

/// A local notification to be shown at a given time.
class PlannedReminder {
  const PlannedReminder({
    required this.id,
    required this.at,
    required this.title,
    required this.body,
    this.route = '/home',
    this.requiresWorkout = false,
  });

  final int id;
  final DateTime at;
  final String title;
  final String body;
  final String route;

  /// Only shown if a workout is still running when it fires.
  final bool requiresWorkout;

  Map<String, Object?> toMap() => {
    'id': id,
    'at': at.millisecondsSinceEpoch,
    'title': title,
    'body': body,
    'route': route,
    'requiresWorkout': requiresWorkout,
  };
}

const streakReminderId = 1;
const unfinishedWorkoutReminderId = 2;

/// Reminder on the last day the weekly goal can still be met, at [hour].
PlannedReminder? planStreakReminder(
  StreakInfo streak, {
  DateTime? now,
  int hour = 18,
}) {
  final t = now ?? DateTime.now();
  final needed = streak.goal - streak.daysThisWeek;
  if (needed <= 0) return null;

  final monday = weekStart(t);
  final lastChance = DateTime(
    monday.year,
    monday.month,
    monday.day + 6 - (needed - 1),
    hour,
  );
  final today = dayOf(t);
  final trainedToday = streak.trainedDays.contains(today);
  // Training today already counts, so the earliest useful reminder is tomorrow.
  if (trainedToday && dayOf(lastChance) == today) return null;
  if (!lastChance.isAfter(t)) return null;

  final title = streak.current > 0
      ? '🔥 A tua streak de ${streak.current} ${streak.current == 1 ? 'semana' : 'semanas'} está em risco'
      : 'Objetivo semanal em risco';
  final body = needed == 1
      ? 'Hoje é o último dia para cumprires o objetivo desta semana. Bora treinar?'
      : 'Faltam $needed treinos e restam $needed dias. Treina hoje para não perderes a semana.';
  return PlannedReminder(
    id: streakReminderId,
    at: lastChance,
    title: title,
    body: body,
    route: '/train',
  );
}

/// Nudge when a workout seems forgotten: 90 minutes after the last change,
/// and never before 3 hours after it started.
PlannedReminder planUnfinishedWorkoutReminder({
  required String name,
  required DateTime startedAt,
  DateTime? now,
}) {
  final t = now ?? DateTime.now();
  final earliest = startedAt.add(const Duration(hours: 3));
  final idle = t.add(const Duration(minutes: 90));
  return PlannedReminder(
    id: unfinishedWorkoutReminderId,
    at: idle.isAfter(earliest) ? idle : earliest,
    title: 'Treino ainda aberto',
    body:
        '"$name" continua a decorrer. Termina-o para guardares o progresso e ganhares XP.',
    route: '/workout',
    requiresWorkout: true,
  );
}
