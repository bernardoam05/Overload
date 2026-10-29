import 'dart:convert';

import '../../domain/enums.dart';
import '../database.dart';

enum AppThemeMode { system, dark, light }

class Profile {
  const Profile({
    this.name = '',
    this.sex = Sex.unspecified,
    this.unit = WeightUnit.kg,
    this.weeklyGoal = 3,
    this.defaultRestSeconds = 90,
    this.themeMode = AppThemeMode.dark,
    this.onboarded = false,
    this.autoRestTimer = true,
    this.restAlerts = true,
    this.liveNotification = true,
    this.reminders = true,
    this.askedNotifications = false,
    this.seenWorkoutTips = false,
  });

  final String name;
  final Sex sex;
  final WeightUnit unit;

  /// Training days per week needed to keep the streak.
  final int weeklyGoal;
  final int defaultRestSeconds;
  final AppThemeMode themeMode;
  final bool onboarded;
  final bool autoRestTimer;

  /// Sound and vibration when the rest timer ends.
  final bool restAlerts;

  /// Ongoing notification (Live Update) while a workout runs.
  final bool liveNotification;

  /// Streak-at-risk and unfinished-workout reminders.
  final bool reminders;

  /// Whether the notification permission prompt was already shown.
  final bool askedNotifications;

  /// Whether the workout gestures tips were dismissed.
  final bool seenWorkoutTips;

  Profile copyWith({
    String? name,
    Sex? sex,
    WeightUnit? unit,
    int? weeklyGoal,
    int? defaultRestSeconds,
    AppThemeMode? themeMode,
    bool? onboarded,
    bool? autoRestTimer,
    bool? restAlerts,
    bool? liveNotification,
    bool? reminders,
    bool? askedNotifications,
    bool? seenWorkoutTips,
  }) => Profile(
    name: name ?? this.name,
    sex: sex ?? this.sex,
    unit: unit ?? this.unit,
    weeklyGoal: (weeklyGoal ?? this.weeklyGoal).clamp(1, 7),
    defaultRestSeconds: (defaultRestSeconds ?? this.defaultRestSeconds).clamp(
      0,
      900,
    ),
    themeMode: themeMode ?? this.themeMode,
    onboarded: onboarded ?? this.onboarded,
    autoRestTimer: autoRestTimer ?? this.autoRestTimer,
    restAlerts: restAlerts ?? this.restAlerts,
    liveNotification: liveNotification ?? this.liveNotification,
    reminders: reminders ?? this.reminders,
    askedNotifications: askedNotifications ?? this.askedNotifications,
    seenWorkoutTips: seenWorkoutTips ?? this.seenWorkoutTips,
  );

  Map<String, Object?> toJson() => {
    'name': name,
    'sex': sex.name,
    'unit': unit.name,
    'weeklyGoal': weeklyGoal,
    'defaultRestSeconds': defaultRestSeconds,
    'themeMode': themeMode.name,
    'onboarded': onboarded,
    'autoRestTimer': autoRestTimer,
    'restAlerts': restAlerts,
    'liveNotification': liveNotification,
    'reminders': reminders,
    'askedNotifications': askedNotifications,
    'seenWorkoutTips': seenWorkoutTips,
  };

  /// Lenient parsing: unknown or missing fields fall back to defaults.
  factory Profile.fromJson(Map<String, Object?> j) {
    const d = Profile();
    T pick<T extends Enum>(List<T> values, Object? raw, T fallback) =>
        values.firstWhere((v) => v.name == raw, orElse: () => fallback);
    return Profile(
      name: j['name'] is String ? j['name']! as String : d.name,
      sex: pick(Sex.values, j['sex'], d.sex),
      unit: pick(WeightUnit.values, j['unit'], d.unit),
      weeklyGoal: j['weeklyGoal'] is int
          ? j['weeklyGoal']! as int
          : d.weeklyGoal,
      defaultRestSeconds: j['defaultRestSeconds'] is int
          ? j['defaultRestSeconds']! as int
          : d.defaultRestSeconds,
      themeMode: pick(AppThemeMode.values, j['themeMode'], d.themeMode),
      onboarded: j['onboarded'] == true,
      autoRestTimer: j['autoRestTimer'] != false,
      restAlerts: j['restAlerts'] != false,
      liveNotification: j['liveNotification'] != false,
      reminders: j['reminders'] != false,
      askedNotifications: j['askedNotifications'] == true,
      seenWorkoutTips: j['seenWorkoutTips'] == true,
    );
  }
}

/// Typed access to the key/value table.
class SettingsRepository {
  SettingsRepository(this._db);
  final AppDatabase _db;

  static const profileKey = 'profile';
  static const activeWorkoutKey = 'active_workout';

  Future<String?> read(String key) async {
    final row = await (_db.select(
      _db.keyValues,
    )..where((k) => k.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Stream<String?> watch(String key) =>
      (_db.select(_db.keyValues)..where((k) => k.key.equals(key)))
          .watchSingleOrNull()
          .map((row) => row?.value);

  Future<void> write(String key, String value) => _db
      .into(_db.keyValues)
      .insertOnConflictUpdate(
        KeyValuesCompanion.insert(key: key, value: value),
      );

  Future<void> remove(String key) =>
      (_db.delete(_db.keyValues)..where((k) => k.key.equals(key))).go();

  // `distinct`: drift re-emits on any key/value write (e.g. the workout draft).
  Stream<Profile> watchProfile() =>
      watch(profileKey).distinct().map(_decodeProfile);

  Future<Profile> readProfile() async => _decodeProfile(await read(profileKey));

  Future<void> saveProfile(Profile p) =>
      write(profileKey, jsonEncode(p.toJson()));

  Profile _decodeProfile(String? raw) {
    if (raw == null) return const Profile();
    try {
      return Profile.fromJson(jsonDecode(raw) as Map<String, Object?>);
    } on FormatException {
      return const Profile();
    }
  }
}
