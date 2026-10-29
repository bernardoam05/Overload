import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../domain/enums.dart';
import '../../domain/exercise.dart';
import '../../widgets/common.dart';
import 'active_workout.dart';
import 'active_workout_controller.dart';

enum FinishChoice { finish, completeFilledAndFinish }

/// Sets that are not done, split by whether their values were typed in.
({int filled, int empty}) pendingSets(
  ActiveWorkout w,
  Map<int, Exercise> library,
) {
  var filled = 0;
  var empty = 0;
  for (final e in w.exercises) {
    final optional = library[e.exerciseId]?.kind != ExerciseKind.weighted;
    for (final s in e.sets.where((s) => !s.done)) {
      isFilled(s, weightOptional: optional) ? filled++ : empty++;
    }
  }
  return (filled: filled, empty: empty);
}

/// Confirmation before finishing, with a short recap so it is worth reading,
/// and a one-tap fix for sets that were filled in but never ticked.
Future<FinishChoice?> showFinishSheet(
  BuildContext context, {
  required ActiveWorkout workout,
  required Map<int, Exercise> library,
  required WeightUnit unit,
}) {
  final pending = pendingSets(workout, library);
  var volume = 0.0;
  for (final e in workout.exercises) {
    if (library[e.exerciseId]?.kind != ExerciseKind.weighted) continue;
    for (final s in e.sets) {
      if (s.done && s.type.isWorking) {
        volume += (s.weightKg ?? 0) * (s.reps ?? 0);
      }
    }
  }
  final exercisesDone = workout.exercises.where((e) => e.doneCount > 0).length;

  return showModalBottomSheet<FinishChoice>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      final theme = Theme.of(context);
      final muted = theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      );
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                workout.isEditing ? 'Guardar alterações?' : 'Terminar treino?',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (!workout.isEditing)
                    Expanded(
                      child: StatTile(
                        value: formatDuration(
                          DateTime.now().difference(workout.startedAt),
                        ),
                        label: 'Duração',
                        icon: Icons.timer_outlined,
                      ),
                    ),
                  Expanded(
                    child: StatTile(
                      value: '${workout.doneSets}',
                      label: 'Séries feitas',
                      icon: Icons.check_rounded,
                    ),
                  ),
                  Expanded(
                    child: StatTile(
                      value: formatVolume(volume, unit),
                      label: 'Volume',
                      icon: Icons.fitness_center_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (pending.filled > 0)
                _Notice(
                  icon: Icons.edit_note_rounded,
                  color: Brand.amber,
                  text: pending.filled == 1
                      ? '1 série tem valores mas não está marcada como feita.'
                      : '${pending.filled} séries têm valores mas não estão marcadas como feitas.',
                ),
              if (pending.empty > 0)
                _Notice(
                  icon: Icons.remove_circle_outline_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                  text: pending.empty == 1
                      ? '1 série vazia vai ser ignorada.'
                      : '${pending.empty} séries vazias vão ser ignoradas.',
                ),
              if (exercisesDone < workout.exercises.length)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Exercícios sem séries feitas não ficam no histórico.',
                    style: muted,
                  ),
                ),
              const SizedBox(height: 8),
              if (pending.filled > 0) ...[
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Brand.success,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () => Navigator.pop(
                    context,
                    FinishChoice.completeFilledAndFinish,
                  ),
                  child: Text(
                    pending.filled == 1
                        ? 'Marcar 1 como feita e terminar'
                        : 'Marcar ${pending.filled} como feitas e terminar',
                  ),
                ),
                const SizedBox(height: 8),
                if (workout.doneSets > 0)
                  OutlinedButton(
                    onPressed: () =>
                        Navigator.pop(context, FinishChoice.finish),
                    child: const Text('Terminar só com as marcadas'),
                  ),
              ] else
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Brand.success,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () => Navigator.pop(context, FinishChoice.finish),
                  child: Text(
                    workout.isEditing ? 'Guardar' : 'Terminar treino',
                  ),
                ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  workout.isEditing
                      ? 'Continuar a editar'
                      : 'Continuar a treinar',
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    ),
  );
}
