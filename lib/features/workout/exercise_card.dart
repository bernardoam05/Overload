import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/format.dart';
import '../../domain/enums.dart';
import '../../domain/exercise.dart';
import '../../domain/models.dart';
import '../../domain/previous.dart';
import '../../domain/records.dart';
import '../../widgets/common.dart';
import 'active_workout.dart';
import 'active_workout_controller.dart';
import 'set_row.dart';

enum _Action { notes, rest, replace, up, down, remove }

/// Rebuilds only when its own exercise changes, so typing in one set does
/// not rebuild every other card of the workout.
class ActiveExerciseCard extends ConsumerWidget {
  const ActiveExerciseCard({
    super.key,
    required this.entryId,
    required this.index,
    required this.total,
  });

  final String entryId;
  final int index;
  final int total;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = ref.watch(
      activeWorkoutProvider.select(
        (w) => w?.exercises.where((e) => e.id == entryId).firstOrNull,
      ),
    );
    if (entry == null) return const SizedBox.shrink();
    return _CardBody(entry: entry, index: index, total: total);
  }
}

class _CardBody extends ConsumerWidget {
  const _CardBody({
    required this.entry,
    required this.index,
    required this.total,
  });

  final ActiveExercise entry;
  final int index;
  final int total;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final exercise = ref.watch(libraryProvider)[entry.exerciseId];
    final profile = ref.watch(currentProfileProvider);
    final previous = ref.watch(previousPerformancesProvider)[entry.exerciseId];
    final record = ref.watch(
      recordsProvider.select((r) => r[entry.exerciseId]),
    );
    final bodyWeight = ref.watch(bodyWeightProvider);
    final controller = ref.read(activeWorkoutProvider.notifier);
    final isEditing = ref.watch(
      activeWorkoutProvider.select((w) => w?.isEditing ?? false),
    );

    if (exercise == null) {
      return const Card(child: ListTile(title: Text('Exercício removido')));
    }
    final kind = exercise.kind;
    final rest = exercise.restSeconds ?? profile.defaultRestSeconds;

    var workingIndex = 0;
    var warmupIndex = 0;
    final rows = <Widget>[];
    for (final (i, set) in entry.sets.indexed) {
      final hint = previous?.match(set.type, warmupIndex, workingIndex);
      if (set.type == SetType.warmup) {
        warmupIndex++;
      } else {
        workingIndex++;
      }
      final comparison =
          set.done && hint != null && set.type.isWorking && set.reps != null
          ? compareSets(
              SetEntry(
                type: set.type,
                weightKg: set.weightKg ?? 0,
                reps: set.reps!,
              ),
              hint,
              kind,
              bodyWeight,
            )
          : null;
      rows.add(
        SetRow(
          key: ValueKey(set.id),
          // First-time users see the first set nudge left to reveal delete.
          peekHint: !profile.seenWorkoutTips && index == 0 && i == 0,
          index: workingIndex,
          set: set,
          kind: kind,
          unit: profile.unit,
          previous: hint,
          comparison: comparison,
          onWeight: (kg) => controller.setWeight(entry.id, set.id, kg),
          onReps: (r) => controller.setReps(entry.id, set.id, r),
          onType: (t) => controller.setType(entry.id, set.id, t),
          onDelete: () {
            final removed = controller.removeSet(entry.id, set.id);
            if (removed == null) return;
            showUndo(
              context,
              'Série removida',
              () => controller.restoreSet(entry.id, removed.$1, removed.$2),
            );
          },
          onToggle: () {
            final wasDone = set.done;
            final ok = controller.toggleDone(
              entry.id,
              set.id,
              hint: hint,
              weightRequired: kind == ExerciseKind.weighted,
              restSeconds: profile.autoRestTimer && !isEditing ? rest : null,
            );
            if (!ok && !wasDone) {
              showMessage(
                context,
                kind == ExerciseKind.duration
                    ? 'Indica a duração da série.'
                    : 'Indica o peso e as repetições.',
              );
            } else if (ok && !isEditing) {
              _celebrateRecord(context, ref, exercise, set.id);
            }
          },
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 14, right: 4),
              child: Row(
                children: [
                  MuscleAvatar(exercise.primaryMuscle, size: 38),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () => context.push('/exercises/${exercise.id}'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            exercise.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          Text(
                            '${exercise.equipment.label} · descanso ${rest == 0 ? 'desligado' : formatSeconds(rest)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  PopupMenuButton<_Action>(
                    icon: const Icon(Icons.more_horiz_rounded),
                    onSelected: (a) => _onAction(context, ref, a, exercise),
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: _Action.notes,
                        child: Text('Notas'),
                      ),
                      const PopupMenuItem(
                        value: _Action.rest,
                        child: Text('Tempo de descanso'),
                      ),
                      const PopupMenuItem(
                        value: _Action.replace,
                        child: Text('Substituir exercício'),
                      ),
                      if (index > 0)
                        const PopupMenuItem(
                          value: _Action.up,
                          child: Text('Mover para cima'),
                        ),
                      if (index < total - 1)
                        const PopupMenuItem(
                          value: _Action.down,
                          child: Text('Mover para baixo'),
                        ),
                      const PopupMenuItem(
                        value: _Action.remove,
                        child: Text('Remover'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (entry.notes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                child: Text(
                  entry.notes,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            _ReferenceLine(
              exercise: exercise,
              previous: previous,
              record: record == null
                  ? null
                  : record[RecordType.forKind(kind).first],
              unit: profile.unit,
            ),
            const SizedBox(height: 6),
            _Header(kind: kind, unit: profile.unit),
            ...rows,
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: TextButton.icon(
                onPressed: () => controller.addSet(entry.id),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Adicionar série'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Shows a toast when the set just completed beats the all-time record
  /// and every earlier set of this exercise in the current workout.
  void _celebrateRecord(
    BuildContext context,
    WidgetRef ref,
    Exercise exercise,
    String setId,
  ) {
    final current = ref
        .read(activeWorkoutProvider)
        ?.exercises
        .where((e) => e.id == entry.id)
        .firstOrNull;
    if (current == null) return;
    final type = RecordType.forKind(exercise.kind).first;
    final bw = ref.read(bodyWeightProvider);
    double value(ActiveSet s) {
      final e = SetEntry(
        type: s.type,
        weightKg: s.weightKg ?? 0,
        reps: s.reps ?? 0,
      );
      return type == RecordType.e1rm
          ? e.e1rm(exercise.kind, bw)
          : e.reps.toDouble();
    }

    final done = current.sets.where((s) => s.done && s.type.isWorking).toList();
    final set = done.where((s) => s.id == setId).firstOrNull;
    final best = ref.read(recordsProvider)[exercise.id]?[type]?.value;
    if (set == null || best == null) return;
    final v = value(set);
    final sessionBest = done
        .where((s) => s.id != setId)
        .fold(0.0, (m, s) => value(s) > m ? value(s) : m);
    if (v <= best + 1e-9 || v <= sessionBest + 1e-9) return;

    HapticFeedback.mediumImpact();
    final unit = ref.read(currentProfileProvider).unit;
    final text = switch (type) {
      RecordType.e1rm => '1RM estimado: ${formatWeight(v, unit)}',
      RecordType.duration => 'Maior duração: ${formatSeconds(v.round())}',
      _ => 'Mais repetições: ${v.round()}',
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Text('🏆', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Novo recorde em ${exercise.name}!\n$text',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 4),
        ),
      );
  }

  Future<void> _onAction(
    BuildContext context,
    WidgetRef ref,
    _Action action,
    Exercise exercise,
  ) async {
    final controller = ref.read(activeWorkoutProvider.notifier);
    switch (action) {
      case _Action.notes:
        final notes = await promptText(
          context,
          title: 'Notas',
          initial: entry.notes,
          maxLines: 4,
          maxLength: 500,
        );
        if (notes != null) controller.setExerciseNotes(entry.id, notes.trim());
      case _Action.rest:
        final seconds = await pickRestSeconds(context, exercise.restSeconds);
        if (seconds != null) {
          await ref
              .read(exerciseRepositoryProvider)
              .setRestSeconds(exercise.id, seconds < 0 ? null : seconds);
        }
      case _Action.replace:
        final ids = await context.push<List<int>>('/exercises/pick?single=1');
        if (ids != null && ids.isNotEmpty) {
          controller.replaceExercise(entry.id, ids.first);
        }
      case _Action.up:
        controller.moveExercise(index, index - 1);
      case _Action.down:
        controller.moveExercise(index, index + 1);
      case _Action.remove:
        final ok = await confirm(
          context,
          title: 'Remover ${exercise.name}?',
          message: entry.doneCount == 0
              ? 'O exercício sai deste treino.'
              : 'As ${entry.doneCount} séries registadas deste exercício serão perdidas.',
          confirmLabel: 'Remover',
          destructive: true,
        );
        if (!ok || !context.mounted) return;
        final removed = controller.removeExercise(entry.id);
        if (removed != null) {
          showUndo(
            context,
            '${exercise.name} removido',
            () => controller.restoreExercise(removed.$1, removed.$2),
          );
        }
    }
  }
}

/// "Last time" and "record" chips: today's target next to the all-time best.
class _ReferenceLine extends StatelessWidget {
  const _ReferenceLine({
    required this.exercise,
    required this.previous,
    required this.record,
    required this.unit,
  });

  final Exercise exercise;
  final PreviousPerformance? previous;
  final PersonalRecord? record;
  final WeightUnit unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    Widget chip(IconData icon, Color color, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    final p = previous;
    final r = record;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      child: p == null
          ? chip(
              Icons.auto_awesome_rounded,
              theme.colorScheme.primary,
              'Primeira vez: hoje defines a referência',
            )
          : Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                chip(
                  Icons.history_rounded,
                  theme.colorScheme.onSurfaceVariant,
                  'Última: ${formatRelativeDay(p.workout.startedAt).toLowerCase()}',
                ),
                if (r != null)
                  chip(Icons.workspace_premium_rounded, Brand.amber, switch (r
                      .type) {
                    RecordType.e1rm =>
                      'Recorde: ${formatSet(r.set, exercise.kind, unit)} · 1RM ${formatWeight(r.value, unit)}',
                    _ => 'Recorde: ${formatSet(r.set, exercise.kind, unit)}',
                  }),
              ],
            ),
    );
  }
}

/// Returns seconds, `-1` for "use default" or `null` when dismissed.
Future<int?> pickRestSeconds(BuildContext context, int? current) {
  const options = [0, 30, 45, 60, 90, 120, 150, 180, 240, 300];
  return showModalBottomSheet<int>(
    context: context,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            title: const Text('Usar predefinição'),
            trailing: current == null ? const Icon(Icons.check) : null,
            onTap: () => Navigator.pop(context, -1),
          ),
          for (final s in options)
            ListTile(
              title: Text(s == 0 ? 'Desligado' : formatSeconds(s)),
              trailing: current == s ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(context, s),
            ),
        ],
      ),
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header({required this.kind, required this.unit});

  final ExerciseKind kind;
  final WeightUnit unit;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      letterSpacing: 0.8,
      fontWeight: FontWeight.w800,
    );
    Widget cell(String t, int flex) => Expanded(
      flex: flex,
      child: Text(t, textAlign: TextAlign.center, style: style),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text('SÉRIE', textAlign: TextAlign.center, style: style),
          ),
          cell('ANTERIOR', 3),
          if (kind != ExerciseKind.duration)
            cell(switch (kind) {
              ExerciseKind.bodyweight => '+${unit.label.toUpperCase()}',
              ExerciseKind.assisted => 'AJUDA',
              _ => unit.label.toUpperCase(),
            }, 2),
          cell(kind == ExerciseKind.duration ? 'TEMPO' : 'REPS', 2),
          SizedBox(
            width: 48,
            child: Icon(Icons.check_rounded, size: 16, color: style?.color),
          ),
        ],
      ),
    );
  }
}
