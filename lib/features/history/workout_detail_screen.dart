import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/format.dart';
import '../../data/repositories/routine_repository.dart';
import '../../domain/enums.dart';
import '../../domain/models.dart';
import '../../widgets/common.dart';
import '../train/routine_editor_screen.dart';
import '../workout/active_workout_controller.dart';
import '../workout/start_workout.dart';

class WorkoutDetailScreen extends ConsumerWidget {
  const WorkoutDetailScreen({super.key, required this.workoutId});

  final int workoutId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final workout = ref
        .watch(historyListProvider)
        .firstWhereOrNull((w) => w.id == workoutId);
    if (workout == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.search_off_rounded,
          title: 'Treino não encontrado',
        ),
      );
    }
    final library = ref.watch(libraryProvider);
    final unit = ref.watch(currentProfileProvider).unit;
    final records = ref.watch(recordsProvider);

    /// A set is highlighted when it still holds an all-time record.
    bool isRecordSet(int exerciseId, SetEntry set) =>
        records[exerciseId]?.values.any(
          (r) => r.workoutId == workout.id && identical(r.set, set),
        ) ??
        false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Treino'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) => _onAction(context, ref, workout, v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Editar treino')),
              PopupMenuItem(
                value: 'routine',
                child: Text('Guardar como rotina'),
              ),
              PopupMenuItem(value: 'delete', child: Text('Apagar')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          Text(workout.name, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            '${capitalize(formatDateLong(workout.startedAt))} · ${formatTime(workout.startedAt)}–${formatTime(workout.endedAt)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: StatTile(
                      value: formatDuration(workout.duration),
                      label: 'Duração',
                    ),
                  ),
                  Expanded(
                    child: StatTile(
                      value: formatVolume(workout.volume(library), unit),
                      label: 'Volume',
                    ),
                  ),
                  Expanded(
                    child: StatTile(
                      value: '${workout.setCount}',
                      label: 'Séries',
                    ),
                  ),
                  Expanded(
                    child: StatTile(value: '${workout.xp}', label: 'XP'),
                  ),
                ],
              ),
            ),
          ),
          if (workout.notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(workout.notes),
              ),
            ),
          ],
          const SizedBox(height: 12),
          for (final entry in workout.exercises) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () =>
                          context.push('/exercises/${entry.exerciseId}'),
                      child: Row(
                        children: [
                          if (library[entry.exerciseId] != null)
                            MuscleAvatar(
                              library[entry.exerciseId]!.primaryMuscle,
                              size: 34,
                            ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              library[entry.exerciseId]?.name ?? 'Exercício',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (entry.notes.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          entry.notes,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    for (final (i, set) in entry.sets.indexed)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 30,
                              child: Text(
                                set.type == SetType.normal
                                    ? '${i + 1}'
                                    : set.type.short,
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            Text(
                              formatSet(
                                set,
                                library[entry.exerciseId]?.kind ??
                                    ExerciseKind.weighted,
                                unit,
                              ),
                              style: theme.textTheme.bodyLarge,
                            ),
                            const Spacer(),
                            if (isRecordSet(entry.exerciseId, set))
                              const Icon(
                                Icons.workspace_premium_rounded,
                                color: Brand.amber,
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () =>
                startWorkout(context, ref, (c) => c.repeat(workout)),
            icon: const Icon(Icons.replay_rounded),
            label: const Text('Repetir este treino'),
          ),
        ],
      ),
    );
  }

  Future<void> _onAction(
    BuildContext context,
    WidgetRef ref,
    WorkoutRecord workout,
    String action,
  ) async {
    switch (action) {
      case 'edit':
        if (ref.read(activeWorkoutProvider) != null) {
          showMessage(
            context,
            'Termina ou cancela o treino em curso primeiro.',
          );
          return;
        }
        ref.read(activeWorkoutProvider.notifier).edit(workout);
        context.push('/workout');
      case 'routine':
        context.push(
          '/routines/new',
          extra: RoutineTemplate(workout.name, [
            for (final e in workout.exercises)
              RoutineItem(
                exerciseId: e.exerciseId,
                sets: e.workingSets.isEmpty
                    ? e.sets.length
                    : e.workingSets.length,
                reps: (e.workingSets.firstOrNull ?? e.sets.first).reps,
              ),
          ]),
        );
      case 'delete':
        final ok = await confirm(
          context,
          title: 'Apagar treino?',
          message: 'O XP e os recordes deste treino deixam de contar.',
          confirmLabel: 'Apagar',
          destructive: true,
        );
        if (!ok) return;
        await ref.read(workoutRepositoryProvider).delete(workout.id);
        if (context.mounted) context.pop();
    }
  }
}
