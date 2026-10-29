import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/providers.dart';
import 'app/router.dart';
import 'app/theme.dart';
import 'data/database.dart';
import 'data/repositories/settings_repository.dart';
import 'features/notifications/notification_sync.dart';
import 'features/workout/active_workout.dart';
import 'features/workout/active_workout_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_PT');

  final db = AppDatabase();
  final settings = SettingsRepository(db);
  final profile = await settings.readProfile();
  final draft = await _restoreDraft(settings);

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        initialProfileProvider.overrideWithValue(profile),
        initialActiveWorkoutProvider.overrideWithValue(draft),
      ],
      child: const OverloadApp(),
    ),
  );
}

/// The workout in progress survives the app being killed.
Future<ActiveWorkout?> _restoreDraft(SettingsRepository settings) async {
  final raw = await settings.read(SettingsRepository.activeWorkoutKey);
  if (raw == null) return null;
  try {
    return ActiveWorkout.fromJson(jsonDecode(raw) as Map<String, Object?>);
  } on Object {
    await settings.remove(SettingsRepository.activeWorkoutKey);
    return null;
  }
}

class OverloadApp extends ConsumerWidget {
  const OverloadApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    return MaterialApp.router(
      title: 'Overload',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: switch (profile.themeMode) {
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.dark => ThemeMode.dark,
        AppThemeMode.light => ThemeMode.light,
      },
      locale: const Locale('pt', 'PT'),
      supportedLocales: const [Locale('pt', 'PT'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) =>
          NotificationSync(child: child ?? const SizedBox.shrink()),
    );
  }
}
