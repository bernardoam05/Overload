import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../domain/enums.dart';
import '../../domain/exercise.dart';
import '../../widgets/common.dart';
import 'active_workout.dart';
import 'active_workout_controller.dart';
import 'routine_sync.dart';

enum FinishChoice { finish, completeFilledAndFinish }

/// What the user chose in the finish sheet, including which changes to take
/// to the routine (empty to leave it as it was).
typedef FinishResult = ({FinishChoice choice, Set<String> routineChanges});

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
///
/// When the workout came from a routine and its structure or pinned notes
/// changed, [sync] lists those changes so the user picks which ones the
/// routine keeps.
Future<FinishResult?> showFinishSheet(
  BuildContext context, {
  required ActiveWorkout workout,
  required Map<int, Exercise> library,
  required WeightUnit unit,
  RoutineSync? sync,
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

  final selected = {...?sync?.defaultSelection};
  FinishResult result(FinishChoice c) => (choice: c, routineChanges: selected);

  return showModalBottomSheet<FinishResult>(
    context: context,
    isScrollControlled: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheetState) {
        final theme = Theme.of(context);
        final muted = theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        );
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  workout.isEditing
                      ? 'Guardar alterações?'
                      : 'Terminar treino?',
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
                if (sync != null)
                  RoutineChangesList(
                    sync: sync,
                    selected: selected,
                    onChanged: (id, on) => setSheetState(
                      () => on ? selected.add(id) : selected.remove(id),
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
                      result(FinishChoice.completeFilledAndFinish),
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
                          Navigator.pop(context, result(FinishChoice.finish)),
                      child: const Text('Terminar só com as marcadas'),
                    ),
                ] else
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Brand.success,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: () =>
                        Navigator.pop(context, result(FinishChoice.finish)),
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
    ),
  );
}

/// Checklist of what changed compared with the routine.
class RoutineChangesList extends StatelessWidget {
  const RoutineChangesList({
    super.key,
    required this.sync,
    required this.selected,
    required this.onChanged,
  });

  final RoutineSync sync;
  final Set<String> selected;
  final void Function(String id, bool on) onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Material, not a coloured box, so the checkbox rows show their ripple.
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Material(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Levar para a rotina «${sync.routine.routine.name}»?',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 2),
              Text(
                'Só o que marcares muda a rotina. O resto fica apenas neste treino.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              for (final c in sync.changes)
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: selected.contains(c.id),
                  onChanged: (v) => onChanged(c.id, v ?? false),
                  title: Text(c.title),
                  subtitle: c.detail == null
                      ? null
                      : Text(
                          c.detail!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }
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
