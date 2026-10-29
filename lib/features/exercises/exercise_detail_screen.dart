import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../data/aliases.dart';
import '../../app/theme.dart';
import '../../core/format.dart';
import '../../domain/enums.dart';
import '../../domain/exercise.dart';
import '../../domain/one_rm.dart';
import '../../domain/records.dart';
import '../../domain/stats.dart';
import '../../widgets/common.dart';
import '../../widgets/line_chart.dart';
import '../workout/workout_summary_screen.dart';

class ExerciseDetailScreen extends ConsumerWidget {
  const ExerciseDetailScreen({super.key, required this.exerciseId});

  final int exerciseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercise = ref.watch(libraryProvider)[exerciseId];
    if (exercise == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.help_outline,
          title: 'Exercício não encontrado',
        ),
      );
    }
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(exercise.name),
          actions: [
            if (exercise.isCustom)
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'edit') {
                    context.push('/exercises/${exercise.id}/edit');
                  } else if (v == 'delete') {
                    final ok = await confirm(
                      context,
                      title: 'Apagar ${exercise.name}?',
                      message:
                          'Se já tiver sido usado em treinos, fica arquivado para manter o histórico.',
                      confirmLabel: 'Apagar',
                      destructive: true,
                    );
                    if (!ok) return;
                    await ref
                        .read(exerciseRepositoryProvider)
                        .remove(exercise.id);
                    if (context.mounted) context.pop();
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Editar')),
                  PopupMenuItem(value: 'delete', child: Text('Apagar')),
                ],
              ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Resumo'),
              Tab(text: 'Histórico'),
              Tab(text: 'Sobre'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _SummaryTab(exercise: exercise),
            _HistoryTab(exercise: exercise),
            _AboutTab(exercise: exercise),
          ],
        ),
      ),
    );
  }
}

class _SummaryTab extends ConsumerWidget {
  const _SummaryTab({required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final unit = ref.watch(currentProfileProvider).unit;
    final bw = ref.watch(bodyWeightProvider);
    final history = ref.watch(historyListProvider);
    final records = ref.watch(recordsProvider)[exercise.id] ?? const {};
    final points = progressSeries(history, exercise, bodyWeightKg: bw);
    final sessions = sessionsFor(history, exercise.id);
    final metric = RecordType.forKind(exercise.kind).first;
    final best1rm = records[RecordType.e1rm]?.value;

    String valueLabel(double v) => switch (metric) {
      RecordType.e1rm => formatWeight(v, unit, withUnit: false),
      RecordType.duration => formatSeconds(v.round()),
      _ => '${v.round()}',
    };

    if (sessions.isEmpty) {
      return const EmptyState(
        icon: Icons.insights_rounded,
        title: 'Ainda sem registos',
        message:
            'Faz este exercício num treino para veres recordes e progresso.',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 12),
                  child: Text(switch (metric) {
                    RecordType.e1rm => '1RM estimado (${unit.label})',
                    RecordType.duration => 'Maior duração',
                    _ => 'Máximo de repetições',
                  }, style: theme.textTheme.titleSmall),
                ),
                ProgressLineChart(points: points, valueLabel: valueLabel),
              ],
            ),
          ),
        ),
        const SectionHeader('Recordes pessoais'),
        Card(
          child: Column(
            children: [
              for (final type in RecordType.forKind(exercise.kind))
                if (records[type] != null)
                  ListTile(
                    leading: const Icon(
                      Icons.workspace_premium_rounded,
                      color: Brand.amber,
                    ),
                    title: Text(type.label),
                    subtitle: Text(formatDate(records[type]!.achievedAt)),
                    trailing: Text(
                      formatRecordValue(records[type]!, exercise.kind, unit),
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
            ],
          ),
        ),
        if (best1rm != null && exercise.kind == ExerciseKind.weighted) ...[
          const SectionHeader('Tabela de repetições'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final reps in const [1, 2, 3, 5, 8, 10, 12, 15])
                    Container(
                      width: 76,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${reps}RM',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            formatWeight(
                              weightForReps(best1rm, reps),
                              unit,
                              withUnit: false,
                            ),
                            style: theme.textTheme.titleSmall,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
        const SectionHeader('Totais'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: StatTile(
                    value: '${sessions.length}',
                    label: 'Sessões',
                  ),
                ),
                Expanded(
                  child: StatTile(
                    value:
                        '${sessions.fold(0, (s, x) => s + x.entry.workingSets.length)}',
                    label: 'Séries',
                  ),
                ),
                if (exercise.kind == ExerciseKind.weighted)
                  Expanded(
                    child: StatTile(
                      value: formatVolume(
                        sessions.fold(
                          0.0,
                          (s, x) =>
                              s +
                              x.entry.sets.fold(
                                0.0,
                                (a, set) => a + set.volume(exercise.kind),
                              ),
                        ),
                        unit,
                      ),
                      label: 'Volume',
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HistoryTab extends ConsumerWidget {
  const _HistoryTab({required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final unit = ref.watch(currentProfileProvider).unit;
    final sessions = sessionsFor(ref.watch(historyListProvider), exercise.id);
    if (sessions.isEmpty) {
      return const EmptyState(
        icon: Icons.history_rounded,
        title: 'Sem histórico',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: sessions.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final s = sessions[i];
        return Card(
          child: InkWell(
            onTap: () => context.push('/workouts/${s.workout.id}'),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.workout.name, style: theme.textTheme.titleSmall),
                  Text(
                    capitalize(formatDate(s.workout.startedAt)),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final (j, set) in s.entry.sets.indexed)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 28,
                            child: Text(
                              set.type.short.isEmpty
                                  ? '${j + 1}'
                                  : set.type.short,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          Text(formatSet(set, exercise.kind, unit)),
                          const Spacer(),
                          if (exercise.kind == ExerciseKind.weighted)
                            Text(
                              '1RM ${formatWeight(set.e1rm(exercise.kind, 0), unit)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AboutTab extends StatelessWidget {
  const _AboutTab({required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Column(
            children: [
              ListTile(
                leading: MuscleAvatar(exercise.primaryMuscle),
                title: const Text('Músculo principal'),
                subtitle: Text(exercise.primaryMuscle.label),
              ),
              if (exercise.secondaryMuscles.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.account_tree_outlined),
                  title: const Text('Músculos secundários'),
                  subtitle: Text(
                    exercise.secondaryMuscles.map((m) => m.label).join(', '),
                  ),
                ),
              ListTile(
                leading: const Icon(Icons.fitness_center),
                title: const Text('Equipamento'),
                subtitle: Text(exercise.equipment.label),
              ),
              ListTile(
                leading: const Icon(Icons.straighten_rounded),
                title: const Text('Registo'),
                subtitle: Text(exercise.kind.label),
              ),
              ListTile(
                leading: const Icon(Icons.military_tech_outlined),
                title: const Text('Conta para ranks'),
                subtitle: Text(
                  exercise.rankGroup == null
                      ? 'Não'
                      : 'Sim — ${exercise.rankGroup!.label} (equivale a ${exercise.rankGroup!.benchmark.toLowerCase()})',
                ),
              ),
            ],
          ),
        ),
        if (exerciseAliases[exercise.seedKey] case final aliases?
            when aliases.isNotEmpty) ...[
          const SectionHeader('Também conhecido como'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final a in aliases) Chip(label: Text(a))],
          ),
        ],
        if (exercise.instructions.isNotEmpty) ...[
          const SectionHeader('Execução'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                exercise.instructions,
                style: theme.textTheme.bodyLarge,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
