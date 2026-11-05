import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/format.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/enums.dart';
import '../../domain/exercise.dart';
import '../../domain/models.dart';
import '../../domain/overload.dart';
import '../../domain/previous.dart';
import '../../domain/superset.dart';
import 'active_workout.dart';

/// Today's aim for each set of [entry]. With progression hints off, only the
/// routine's targets (and its planned load, the first time) are used.
Progression progressionFor(
  ActiveExercise entry,
  PreviousPerformance? previous,
  Exercise exercise,
  Profile profile,
) {
  final plan = [for (final s in entry.sets) PlannedSet(s.type, s.targetReps)];
  if (!profile.progressionHints) {
    return Progression(
      sets: [
        for (final p in plan)
          p.isMain && (p.targetReps != null || entry.plannedWeightKg != null)
              ? SetAim(
                  weightKg: previous == null ? entry.plannedWeightKg : null,
                  reps: p.targetReps,
                )
              : null,
      ],
    );
  }
  return suggestProgression(
    plan: plan,
    previousMain: [
      for (final s in previous?.working ?? const <SetEntry>[])
        if (s.type == SetType.normal || s.type == SetType.failure) s,
    ],
    exercise: exercise,
    unit: profile.unit,
    plannedWeightKg: entry.plannedWeightKg,
  );
}

/// Superset membership of the exercise at [index]: its group, its position
/// in the group and the group's size, or `null` when done on its own.
({int group, int position, int size})? supersetOf(ActiveWorkout? w, int index) {
  if (w == null || index < 0 || index >= w.exercises.length) return null;
  final groups = supersetGroups([for (final e in w.exercises) e.supersetNext]);
  final g = groups[index];
  if (g == null) return null;
  final members = [
    for (final (i, x) in groups.indexed)
      if (x == g) i,
  ];
  return (group: g, position: members.indexOf(index), size: members.length);
}

/// One line saying what to do today to progress.
class OverloadLine extends StatelessWidget {
  const OverloadLine({
    super.key,
    required this.progression,
    required this.entry,
    required this.exercise,
    required this.unit,
  });

  final Progression progression;
  final ActiveExercise entry;
  final Exercise exercise;
  final WeightUnit unit;

  String? _text() {
    final targets = [for (final s in entry.sets) ?s.targetReps];
    final seconds = exercise.kind == ExerciseKind.duration;
    String goal() => seconds
        ? targets.map((t) => formatSeconds(t)).join(' · ')
        : '${targets.join(' · ')} reps';
    return switch (progression.advice) {
      null => null,
      OverloadAdvice.start =>
        targets.isEmpty ? null : 'Objetivo de hoje: ${goal()}',
      OverloadAdvice.addLoad when exercise.kind == ExerciseKind.assisted =>
        'Cumpriste o objetivo: menos ajuda, ${formatWeight(progression.toKg!, unit)}',
      OverloadAdvice.addLoad =>
        'Cumpriste o objetivo: sobe para ${formatWeight(progression.toKg!, unit)}',
      OverloadAdvice.reachTargets =>
        'Mantém a carga e chega às reps alvo (${goal()})',
      OverloadAdvice.addReps =>
        targets.isEmpty
            ? 'Mesma carga, mais 1 rep em cada série'
            : 'Já chegas ao alvo: mais 1 rep em cada série',
      OverloadAdvice.addTime => 'Mais $timeIncrementSeconds s em cada série',
    };
  }

  @override
  Widget build(BuildContext context) {
    final text = _text();
    if (text == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final color = progression.advice == OverloadAdvice.addLoad
        ? theme.colorScheme.primary
        : theme.colorScheme.tertiary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Icons.trending_up_rounded, size: 16, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "SUPERSÉRIE A · 1/2" above an exercise that belongs to a superset.
class SupersetBadge extends StatelessWidget {
  const SupersetBadge({super.key, required this.membership});

  final ({int group, int position, int size}) membership;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.secondary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: Row(
        children: [
          Icon(Icons.link_rounded, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            'SUPERSÉRIE ${supersetLetter(membership.group)} · '
            '${membership.position + 1}/${membership.size}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              membership.position < membership.size - 1
                  ? 'sem descanso até ao seguinte'
                  : 'descanso depois deste',
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The exercise's recorded equipment setup; tapping edits it.
class SetupLine extends StatelessWidget {
  const SetupLine({super.key, required this.exercise, required this.onTap});

  final Exercise exercise;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final summary = exercise.setupSummary;
    if (summary == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
        child: Row(
          children: [
            Icon(
              Icons.tune_rounded,
              size: 16,
              color: theme.colorScheme.secondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                summary,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Edits an exercise's equipment setup and bench angle (measurable with the
/// phone's inclinometer).
Future<void> editExerciseSetup(
  BuildContext context,
  WidgetRef ref,
  Exercise exercise,
) async {
  final result = await showDialog<({String setup, int? angle})>(
    context: context,
    builder: (_) => _SetupDialog(exercise: exercise),
  );
  if (result == null) return;
  await ref
      .read(exerciseRepositoryProvider)
      .setSetup(exercise.id, setup: result.setup, benchAngle: result.angle);
}

class _SetupDialog extends StatefulWidget {
  const _SetupDialog({required this.exercise});
  final Exercise exercise;

  @override
  State<_SetupDialog> createState() => _SetupDialogState();
}

class _SetupDialogState extends State<_SetupDialog> {
  late final _setup = TextEditingController(text: widget.exercise.setup);
  late int? _angle = widget.exercise.benchAngle;

  @override
  void dispose() {
    _setup.dispose();
    super.dispose();
  }

  Future<void> _measure() async {
    final angle = await context.push<int>(
      '/tools/inclinometer?for=${Uri.encodeComponent(widget.exercise.name)}',
    );
    if (angle != null && mounted) setState(() => _angle = angle);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Afinações'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.exercise.name,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _setup,
            maxLength: 120,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Assento, pega, pinos…',
              hintText: 'Ex.: assento 4, pega neutra',
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.architecture_rounded, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _angle == null
                      ? 'Sem ângulo de banco'
                      : 'Banco: ${formatAngle(_angle!)}',
                  style: theme.textTheme.titleSmall,
                ),
              ),
              if (_angle != null)
                IconButton(
                  tooltip: 'Remover ângulo',
                  onPressed: () => setState(() => _angle = null),
                  icon: const Icon(Icons.close_rounded),
                ),
            ],
          ),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: _measure,
            icon: const Icon(Icons.screen_rotation_alt_rounded),
            label: const Text('Medir com o telemóvel'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, (
            setup: _setup.text.trim(),
            angle: _angle,
          )),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
