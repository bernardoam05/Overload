import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/format.dart';
import '../../domain/models.dart';

/// Compact card summarising a finished workout.
class WorkoutTile extends ConsumerWidget {
  const WorkoutTile({super.key, required this.workout});

  final WorkoutRecord workout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final library = ref.watch(libraryProvider);
    final unit = ref.watch(currentProfileProvider).unit;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final lines = workout.exercises.take(4).map((e) {
      final name = library[e.exerciseId]?.name ?? 'Exercício';
      return '${e.workingSets.length}× $name';
    }).toList();
    if (workout.exercises.length > 4) {
      lines.add('+${workout.exercises.length - 4} exercícios');
    }

    return Card(
      child: InkWell(
        onTap: () => context.push('/workouts/${workout.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      workout.name,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  if (workout.xp > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondary.withValues(
                          alpha: 0.15,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '+${workout.xp} XP',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.secondary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${capitalize(formatRelativeDay(workout.startedAt))} · ${formatTime(workout.startedAt)}',
                style: muted,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _Chip(
                    icon: Icons.timer_outlined,
                    text: formatDuration(workout.duration),
                  ),
                  const SizedBox(width: 16),
                  _Chip(
                    icon: Icons.fitness_center_rounded,
                    text: formatVolume(workout.volume(library), unit),
                  ),
                  const SizedBox(width: 16),
                  _Chip(
                    icon: Icons.repeat_rounded,
                    text: '${workout.setCount} séries',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(lines.join('\n'), style: muted?.copyWith(height: 1.5)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.primary),
        const SizedBox(width: 4),
        Text(text, style: theme.textTheme.labelLarge),
      ],
    );
  }
}
