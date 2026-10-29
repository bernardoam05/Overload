import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../domain/exercise.dart';
import '../../domain/reminders.dart';
import '../../services/notification_bridge.dart';
import '../workout/active_workout.dart';
import '../workout/active_workout_controller.dart';

final notificationBridgeProvider = Provider((ref) => NotificationBridge());

/// Builds the live notification content for [w].
WorkoutNotice workoutNotice(
  ActiveWorkout w,
  Map<int, Exercise> library, {
  required bool restAlerts,
  required bool showOngoing,
}) {
  String? next;
  for (final e in w.exercises) {
    final i = e.sets.indexWhere((s) => !s.done);
    if (i >= 0) {
      final name = library[e.exerciseId]?.name ?? 'Exercício';
      next = '$name · série ${i + 1} de ${e.sets.length}';
      break;
    }
  }
  return WorkoutNotice(
    name: w.name,
    startedAt: w.startedAt,
    setsDone: w.doneSets,
    setsTotal: w.exercises.fold(0, (s, e) => s + e.sets.length),
    segments: [for (final e in w.exercises) e.sets.length],
    nextLabel: next,
    restEndsAt: w.restEndsAt,
    restTotalSeconds: w.restTotalSeconds,
    restAlerts: restAlerts,
    showOngoing: showOngoing,
  );
}

/// Keeps system notifications in sync with the app state and routes
/// notification taps and buttons back into the app.
class NotificationSync extends ConsumerStatefulWidget {
  const NotificationSync({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<NotificationSync> createState() => _NotificationSyncState();
}

class _NotificationSyncState extends ConsumerState<NotificationSync>
    with WidgetsBindingObserver {
  String? _lastWorkout;
  String? _lastReminders;

  NotificationBridge get _bridge => ref.read(notificationBridgeProvider);

  @override
  void initState() {
    super.initState();
    if (!_bridge.enabled) return;
    WidgetsBinding.instance.addObserver(this);
    _bridge.setHandlers(onAction: _onAction, onOpenRoute: _openRoute);

    ref.listenManual(activeWorkoutProvider, (previous, next) {
      if (previous == null && next != null && !next.isEditing) {
        unawaited(_askPermissionOnce());
      }
      _syncWorkout();
      _syncReminders();
    });
    ref.listenManual(libraryProvider, (_, _) => _syncWorkout());
    ref.listenManual(currentProfileProvider, (_, _) {
      _syncWorkout();
      _syncReminders();
    });
    ref.listenManual(streakProvider, (_, _) => _syncReminders());

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _drainActions();
      _syncWorkout();
      _syncReminders();
      final route = await _bridge.takeLaunchRoute();
      if (route != null) _openRoute(route);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    unawaited(_bridge.cancelRestAlert());
    unawaited(_drainActions());
    _syncReminders();
  }

  Future<void> _drainActions() async {
    for (final action in await _bridge.takePendingActions()) {
      _onAction(action);
    }
  }

  void _onAction(String action) {
    final controller = ref.read(activeWorkoutProvider.notifier);
    switch (action) {
      case 'rest_plus':
        controller.adjustRest(15);
      case 'rest_minus':
        controller.adjustRest(-15);
      case 'rest_skip':
        controller.skipRest();
      case 'rest_done':
        controller.clearRestIfDue();
    }
  }

  void _openRoute(String route) {
    final router = ref.read(routerProvider);
    final active = ref.read(activeWorkoutProvider) != null;
    if (route == '/workout') {
      if (!active) return;
      if (router.state.matchedLocation != '/workout') router.push('/workout');
    } else {
      router.go(route);
    }
  }

  Future<void> _askPermissionOnce() async {
    final profile = ref.read(currentProfileProvider);
    if (profile.askedNotifications) return;
    await ref
        .read(settingsRepositoryProvider)
        .saveProfile(profile.copyWith(askedNotifications: true));
    await _bridge.requestPermission();
    _lastWorkout = null;
    _syncWorkout();
  }

  void _syncWorkout() {
    final w = ref.read(activeWorkoutProvider);
    if (w == null || w.isEditing) {
      if (_lastWorkout != '') unawaited(_bridge.clearWorkout());
      _lastWorkout = '';
      return;
    }
    final profile = ref.read(currentProfileProvider);
    final notice = workoutNotice(
      w,
      ref.read(libraryProvider),
      restAlerts: profile.restAlerts,
      showOngoing: profile.liveNotification,
    );
    final key = jsonEncode(notice.toMap());
    if (key == _lastWorkout) return;
    _lastWorkout = key;
    unawaited(_bridge.updateWorkout(notice));
  }

  void _syncReminders() {
    final profile = ref.read(currentProfileProvider);
    final reminders = <PlannedReminder>[];
    if (profile.reminders) {
      if (ref.read(historyListProvider).isNotEmpty) {
        final streak = planStreakReminder(ref.read(streakProvider));
        if (streak != null) reminders.add(streak);
      }
      final w = ref.read(activeWorkoutProvider);
      if (w != null && !w.isEditing) {
        reminders.add(
          planUnfinishedWorkoutReminder(name: w.name, startedAt: w.startedAt),
        );
      }
    }
    // Rounded to the minute so frequent workout edits don't reschedule.
    final key = jsonEncode([
      for (final r in reminders)
        {...r.toMap(), 'at': r.at.millisecondsSinceEpoch ~/ 60000},
    ]);
    if (key == _lastReminders) return;
    _lastReminders = key;
    unawaited(_bridge.setReminders(reminders));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
