import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/format.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/enums.dart';
import '../../domain/exercise.dart';
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
  Profile profile, {
  List<SessionLog> recent = const [],
  double bodyWeightKg = 0,
}) {
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
    recent: recent,
    exercise: exercise,
    unit: profile.unit,
    plannedWeightKg: entry.plannedWeightKg,
    range: repRangeFor(exercise, profile.repRange),
    bodyWeightKg: bodyWeightKg,
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

/// Whether exercise [index] is the one being done now, so its form and tips
/// row shows before the first set:
/// it is the first, it has started, or the exercise before it is complete.
/// A superset counts as one block: all its exercises are current as soon as
/// the block before is complete or any of them has started.
bool isCurrentExercise(ActiveWorkout? w, int index) {
  if (w == null || index < 0 || index >= w.exercises.length) return false;
  final exercises = w.exercises;
  final groups = supersetGroups([for (final e in exercises) e.supersetNext]);
  final group = groups[index];
  var first = index;
  var last = index;
  if (group != null) {
    while (first > 0 && groups[first - 1] == group) {
      first--;
    }
    while (last < exercises.length - 1 && groups[last + 1] == group) {
      last++;
    }
  }
  bool complete(ActiveExercise e) =>
      e.sets.isNotEmpty && e.sets.every((s) => s.done);
  if (first == 0) return true;
  for (var i = first; i <= last; i++) {
    if (exercises[i].doneCount > 0) return true;
  }
  // The block right before: one exercise, or a whole superset.
  final before = groups[first - 1];
  var start = first - 1;
  if (before != null) {
    while (start > 0 && groups[start - 1] == before) {
      start--;
    }
  }
  for (var i = start; i < first; i++) {
    if (!complete(exercises[i])) return false;
  }
  return true;
}

/// One line saying what to do today to progress.
class OverloadLine extends StatelessWidget {
  const OverloadLine({
    super.key,
    required this.progression,
    required this.entry,
    required this.exercise,
    required this.unit,
    this.range,
  });

  /// Rep range, when the routine sets no targets.
  final RepRange? range;
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
    String kg() => formatWeight(progression.toKg ?? 0, unit);
    final range = targets.isEmpty ? this.range : null;
    return switch (progression.advice) {
      null => null,
      OverloadAdvice.start =>
        targets.isNotEmpty
            ? 'Objetivo de hoje: ${goal()}'
            : range == null
            ? null
            : 'Objetivo: ${range.min}–${range.max} reps em cada série',
      OverloadAdvice.reduceLoad when progression.byForm =>
        'Forma má 2 treinos seguidos: baixa para ${kg()} e acerta a técnica',
      OverloadAdvice.reduceLoad =>
        'Pior 2 treinos seguidos: baixa para ${kg()} e volta a construir',
      OverloadAdvice.deload =>
        '3 treinos sem progresso: deload para ${kg()} (cerca de −10 %)',
      OverloadAdvice.focusForm =>
        'A forma foi má da última vez: mesma carga, foca na técnica',
      OverloadAdvice.addLoad when exercise.kind == ExerciseKind.assisted =>
        'Cumpriste o objetivo: menos ajuda, ${formatWeight(progression.toKg!, unit)}',
      OverloadAdvice.addLoad =>
        'Cumpriste o objetivo: sobe para ${formatWeight(progression.toKg!, unit)}',
      OverloadAdvice.reachTargets when targets.isEmpty && range != null =>
        'Mantém a carga e sobe até às ${range.max} reps',
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
    final down = switch (progression.advice) {
      OverloadAdvice.reduceLoad ||
      OverloadAdvice.deload ||
      OverloadAdvice.focusForm => true,
      _ => false,
    };
    final color = down
        ? Brand.amber
        : progression.advice == OverloadAdvice.addLoad
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
            Icon(
              down ? Icons.trending_down_rounded : Icons.trending_up_rounded,
              size: 16,
              color: color,
            ),
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

/// "Forma: Má · OK · Boa" with a link to the technique cues, on the current
/// exercise (see [isCurrentExercise]) and on any exercise already started.
class FormRow extends StatelessWidget {
  const FormRow({
    super.key,
    required this.entry,
    required this.exercise,
    required this.onRate,
  });

  final ActiveExercise entry;
  final Exercise exercise;
  final ValueChanged<FormRating> onRate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = theme.colorScheme;
    final rated = entry.form;
    Color colorOf(FormRating r) => switch (r) {
      FormRating.bad => c.error,
      FormRating.ok => Brand.amber,
      FormRating.good => Brand.success,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 8, 0),
      child: Row(
        children: [
          Text(
            'Forma',
            style: theme.textTheme.labelMedium?.copyWith(
              color: c.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          for (final r in FormRating.values)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(r.label),
                selected: rated == r,
                visualDensity: VisualDensity.compact,
                selectedColor: colorOf(r).withValues(alpha: 0.22),
                labelStyle: TextStyle(
                  color: rated == r ? colorOf(r) : null,
                  fontWeight: rated == r ? FontWeight.w800 : null,
                ),
                showCheckmark: false,
                onSelected: (_) => onRate(r),
              ),
            ),
          const Spacer(),
          if (exercise.hasGuide)
            TextButton(
              onPressed: () => showExerciseGuide(context, exercise),
              child: const Text('Dicas'),
            ),
        ],
      ),
    );
  }
}

/// Small "Dicas de execução" line with the first cue, shown before any set
/// of the exercise is done.
class GuideLink extends StatelessWidget {
  const GuideLink({super.key, required this.exercise});
  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    if (!exercise.hasGuide) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => showExerciseGuide(context, exercise),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
        child: Row(
          children: [
            Icon(
              Icons.tips_and_updates_outlined,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                exercise.cueList.isEmpty
                    ? 'Dicas de execução'
                    : exercise.cueList.first,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Text(
              'Dicas',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Technique cues, the common mistake and how form affects progression.
Future<void> showExerciseGuide(
  BuildContext context,
  Exercise exercise,
) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (context) {
    final theme = Theme.of(context);
    final c = theme.colorScheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              exercise.name,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            if (exercise.instructions.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                exercise.instructions,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: c.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 16),
            for (final (i, cue) in exercise.cueList.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      margin: const EdgeInsets.only(right: 10, top: 1),
                      decoration: BoxDecoration(
                        color: c.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${i + 1}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: c.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(cue, style: theme.textTheme.bodyMedium),
                    ),
                  ],
                ),
              ),
            if (exercise.mistake.trim().isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Brand.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 18,
                      color: Brand.amber,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Erro comum: ${exercise.mistake.trim()}',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Text(
              'No fim do exercício, regista como foi a forma. Com forma má a '
              'app não sugere mais carga, e duas vezes seguidas sugere baixar.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: c.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  },
);
