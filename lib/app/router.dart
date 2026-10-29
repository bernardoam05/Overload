import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/exercises/exercise_detail_screen.dart';
import '../features/exercises/exercise_editor_screen.dart';
import '../features/exercises/exercises_screen.dart';
import '../features/history/history_screen.dart';
import '../features/history/workout_detail_screen.dart';
import '../features/home/home_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/profile/achievements_screen.dart';
import '../features/profile/body_weight_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/ranks/ranks_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/tools/tools_screen.dart';
import '../features/train/routine_editor_screen.dart';
import '../features/train/train_screen.dart';
import '../features/workout/active_workout_controller.dart';
import '../features/workout/active_workout_screen.dart';
import '../features/workout/workout_summary_screen.dart';
import 'providers.dart';
import 'shell.dart';

final _rootKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final onboarded = ValueNotifier<bool>(
    ref.read(initialProfileProvider).onboarded,
  );
  ref.listen(profileProvider, (_, next) {
    final value = next.value?.onboarded;
    if (value != null) onboarded.value = value;
  });
  ref.onDispose(onboarded.dispose);

  int? idParam(GoRouterState s) => int.tryParse(s.pathParameters['id'] ?? '');

  final router = GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/home',
    refreshListenable: onboarded,
    redirect: (context, state) {
      final atOnboarding = state.matchedLocation == '/onboarding';
      if (!onboarded.value) return atOnboarding ? null : '/onboarding';
      if (atOnboarding) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
      StatefulShellRoute(
        builder: (context, state, shell) => AppShell(shell: shell),
        navigatorContainerBuilder: (context, shell, children) =>
            SwipeableBranches(shell: shell, children: children),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/train', builder: (_, _) => const TrainScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/ranks', builder: (_, _) => const RanksScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/history',
                builder: (_, _) => const HistoryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (_, _) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/workout',
        parentNavigatorKey: _rootKey,
        pageBuilder: (_, _) => const MaterialPage(
          fullscreenDialog: true,
          child: ActiveWorkoutScreen(),
        ),
      ),
      GoRoute(
        path: '/summary',
        parentNavigatorKey: _rootKey,
        // The summary only lives in memory; after a restart fall back home.
        redirect: (_, s) => s.extra is WorkoutSummary ? null : '/home',
        builder: (_, s) =>
            WorkoutSummaryScreen(summary: s.extra! as WorkoutSummary),
      ),
      GoRoute(
        path: '/workouts/:id',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => WorkoutDetailScreen(workoutId: idParam(s) ?? -1),
      ),
      GoRoute(
        path: '/exercises',
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const ExercisesScreen(),
        routes: [
          GoRoute(
            path: 'pick',
            parentNavigatorKey: _rootKey,
            pageBuilder: (_, s) => MaterialPage(
              fullscreenDialog: true,
              child: ExercisesScreen(
                pickMode: s.uri.queryParameters['single'] == '1'
                    ? PickMode.single
                    : PickMode.multiple,
              ),
            ),
          ),
          GoRoute(
            path: 'new',
            parentNavigatorKey: _rootKey,
            builder: (_, _) => const ExerciseEditorScreen(),
          ),
          GoRoute(
            path: ':id',
            parentNavigatorKey: _rootKey,
            builder: (_, s) =>
                ExerciseDetailScreen(exerciseId: idParam(s) ?? -1),
            routes: [
              GoRoute(
                path: 'edit',
                parentNavigatorKey: _rootKey,
                builder: (_, s) => ExerciseEditorScreen(exerciseId: idParam(s)),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/routines/new',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => RoutineEditorScreen(
          template: s.extra is RoutineTemplate
              ? s.extra! as RoutineTemplate
              : null,
        ),
      ),
      GoRoute(
        path: '/routines/:id',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => RoutineEditorScreen(routineId: idParam(s)),
      ),
      GoRoute(
        path: '/body-weight',
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const BodyWeightScreen(),
      ),
      GoRoute(
        path: '/achievements',
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const AchievementsScreen(),
      ),
      GoRoute(
        path: '/tools',
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const ToolsScreen(),
      ),
      GoRoute(
        path: '/settings',
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const SettingsScreen(),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
