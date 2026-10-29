import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/reminders.dart';

/// What the live workout notification shows.
class WorkoutNotice {
  const WorkoutNotice({
    required this.name,
    required this.startedAt,
    required this.setsDone,
    required this.setsTotal,
    required this.segments,
    required this.nextLabel,
    required this.restEndsAt,
    required this.restTotalSeconds,
    required this.restAlerts,
    required this.showOngoing,
  });

  final String name;
  final DateTime startedAt;
  final int setsDone;
  final int setsTotal;

  /// Planned sets per exercise, drawn as progress segments.
  final List<int> segments;
  final String? nextLabel;
  final DateTime? restEndsAt;
  final int restTotalSeconds;
  final bool restAlerts;
  final bool showOngoing;

  Map<String, Object?> toMap() => {
    'name': name,
    'startedAt': startedAt.millisecondsSinceEpoch,
    'setsDone': setsDone,
    'setsTotal': setsTotal,
    'segments': segments,
    'nextLabel': nextLabel,
    'restEndsAt': restEndsAt?.millisecondsSinceEpoch ?? 0,
    'restTotalSeconds': restTotalSeconds,
    'restAlerts': restAlerts,
    'showOngoing': showOngoing,
  };
}

class NotificationStatus {
  const NotificationStatus({
    required this.notifications,
    required this.promoted,
    required this.exactAlarms,
  });

  final bool notifications;

  /// Live Updates allowed (`null` before Android 16).
  final bool? promoted;
  final bool exactAlarms;
}

/// Thin wrapper over the native notification code (Android only; a no-op
/// elsewhere, including tests).
class NotificationBridge {
  NotificationBridge({bool? enabled})
    : enabled = enabled ?? (!kIsWeb && Platform.isAndroid && !_isTest);

  static bool get _isTest => Platform.environment.containsKey('FLUTTER_TEST');

  static const _channel = MethodChannel('overload/notifications');

  /// Whether system notifications are available on this platform.
  final bool enabled;

  void setHandlers({
    required void Function(String action) onAction,
    required void Function(String route) onOpenRoute,
  }) {
    if (!enabled) return;
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onAction':
          onAction(call.arguments as String);
        case 'openRoute':
          onOpenRoute(call.arguments as String);
      }
      return null;
    });
  }

  Future<T?> _invoke<T>(String method, [Object? args]) async {
    if (!enabled) return null;
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on PlatformException catch (e) {
      debugPrint('notifications.$method failed: $e');
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  Future<void> updateWorkout(WorkoutNotice notice) =>
      _invoke('updateWorkout', notice.toMap());

  Future<void> clearWorkout() => _invoke('clearWorkout');

  Future<void> cancelRestAlert() => _invoke('cancelRestAlert');

  Future<void> setReminders(List<PlannedReminder> reminders) =>
      _invoke('setReminders', [for (final r in reminders) r.toMap()]);

  Future<List<String>> takePendingActions() async =>
      (await _invoke<List<Object?>>(
        'takePendingActions',
      ))?.whereType<String>().toList() ??
      const [];

  Future<String?> takeLaunchRoute() => _invoke<String>('takeLaunchRoute');

  Future<NotificationStatus?> status() async {
    final m = await _invoke<Map<Object?, Object?>>('status');
    if (m == null) return null;
    return NotificationStatus(
      notifications: m['notifications'] == true,
      promoted: m['promoted'] as bool?,
      exactAlarms: m['exactAlarms'] != false,
    );
  }

  Future<bool> requestPermission() async =>
      await _invoke<bool>('requestPermission') ?? false;

  /// [which]: `null` (app notifications), `promotion` or `exactAlarms`.
  Future<void> openSettings([String? which]) => _invoke('openSettings', which);
}
