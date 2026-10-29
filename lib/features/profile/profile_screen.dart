import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/format.dart';
import '../../domain/enums.dart';
import '../../domain/stats.dart';
import '../../widgets/common.dart';
import 'achievements_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profile = ref.watch(currentProfileProvider);
    final level = ref.watch(levelProvider);
    final history = ref.watch(historyListProvider);
    final library = ref.watch(libraryProvider);
    final achievementsList = ref.watch(achievementsProvider);
    final unlocked = achievementsList.where((a) => a.unlocked).toList();
    final totalTime = history.fold(Duration.zero, (s, w) => s + w.duration);
    final totalVolume = history.fold(0.0, (s, w) => s + w.volume(library));
    final bodyWeights = ref.watch(bodyWeightsProvider).value ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        actions: [
          IconButton(
            tooltip: 'Definições',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Row(
            children: [
              Container(
                width: 68,
                height: 68,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  gradient: Brand.emberGradient,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  profile.name.isEmpty
                      ? '?'
                      : profile.name.characters.first.toUpperCase(),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name.isEmpty ? 'Atleta' : profile.name,
                      style: theme.textTheme.titleLarge,
                    ),
                    Text(
                      'Nível ${level.level} · ${formatNumber(level.totalXp, decimals: 0)} XP',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ProgressBar(
                      value: level.progress,
                      color: theme.colorScheme.secondary,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${level.xpIntoLevel}/${level.xpForLevel} XP para o nível ${level.level + 1}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: StatTile(
                          value: '${history.length}',
                          label: 'Treinos',
                          icon: Icons.event_available_rounded,
                        ),
                      ),
                      Expanded(
                        child: StatTile(
                          value: formatDuration(totalTime),
                          label: 'Tempo total',
                          icon: Icons.timer_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: StatTile(
                          value: formatVolume(totalVolume, profile.unit),
                          label: 'Volume total',
                          icon: Icons.fitness_center_rounded,
                        ),
                      ),
                      Expanded(
                        child: StatTile(
                          value: '${ref.watch(recordBreaksProvider)}',
                          label: 'Recordes batidos',
                          icon: Icons.workspace_premium_outlined,
                          color: Brand.amber,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SectionHeader('Volume semanal'),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 20, 16, 8),
              child: _WeeklyChart(
                buckets: ref.watch(weeklyBucketsProvider),
                unit: profile.unit,
              ),
            ),
          ),
          const SectionHeader('Séries por músculo · 30 dias'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _MuscleBars(
                data: setsPerMuscle(
                  history,
                  library,
                  since: DateTime.now().subtract(const Duration(days: 30)),
                ),
              ),
            ),
          ),
          SectionHeader(
            'Conquistas · ${unlocked.length}/${achievementsList.length}',
            action: 'Ver todas',
            onAction: () => context.push('/achievements'),
          ),
          Card(
            child: InkWell(
              onTap: () => context.push('/achievements'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: unlocked.isEmpty
                    ? Text(
                        'Termina o primeiro treino para desbloquear a primeira conquista.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      )
                    : Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final a in unlocked.reversed.take(8))
                            AchievementMedal(progress: a, size: 44),
                        ],
                      ),
              ),
            ),
          ),
          const SectionHeader('Mais'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.monitor_weight_outlined),
                  title: const Text('Peso corporal'),
                  subtitle: Text(
                    bodyWeights.isEmpty
                        ? 'Sem registos'
                        : '${formatWeight(bodyWeights.first.weightKg, profile.unit)} · ${formatRelativeDay(bodyWeights.first.date).toLowerCase()}',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/body-weight'),
                ),
                ListTile(
                  leading: const Icon(Icons.menu_book_outlined),
                  title: const Text('Biblioteca de exercícios'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/exercises'),
                ),
                ListTile(
                  leading: const Icon(Icons.calculate_outlined),
                  title: const Text('Calculadoras'),
                  subtitle: const Text('1RM e discos'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/tools'),
                ),
                ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: const Text('Definições e backup'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/settings'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyChart extends StatelessWidget {
  const _WeeklyChart({required this.buckets, required this.unit});

  final List<WeekBucket> buckets;
  final WeightUnit unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final values = [for (final b in buckets) toDisplayWeight(b.volume, unit)];
    final maxV = values.fold(0.0, (m, v) => v > m ? v : m);
    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          maxY: maxV <= 0 ? 1 : maxV * 1.15,
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: theme.colorScheme.outlineVariant, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (v, meta) => v == meta.max
                    ? const SizedBox.shrink()
                    : Text(
                        v >= 1000
                            ? '${formatNumber(v / 1000, decimals: 1)}k'
                            : formatNumber(v, decimals: 0),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                getTitlesWidget: (v, meta) {
                  final i = v.toInt();
                  if (i % 3 != 2 && i != buckets.length - 1) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      formatDateShort(buckets[i].start),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => theme.colorScheme.inverseSurface,
              getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                '${formatVolume(buckets[group.x].volume, unit)}\n${buckets[group.x].workouts} treinos',
                TextStyle(
                  color: theme.colorScheme.onInverseSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          barGroups: [
            for (final (i, v) in values.indexed)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: v,
                    width: 14,
                    borderRadius: BorderRadius.circular(5),
                    gradient: i == values.length - 1
                        ? Brand.emberGradient
                        : LinearGradient(
                            colors: [
                              theme.colorScheme.primary.withValues(alpha: 0.45),
                              theme.colorScheme.primary.withValues(alpha: 0.65),
                            ],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _MuscleBars extends StatelessWidget {
  const _MuscleBars({required this.data});

  final Map<Muscle, double> data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = data.entries.where((e) => e.key != Muscle.cardio).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (entries.isEmpty) {
      return Text(
        'Sem treinos nos últimos 30 dias.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }
    final maxV = entries.first.value;
    return Column(
      children: [
        for (final e in entries.take(8))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                SizedBox(
                  width: 96,
                  child: Text(e.key.label, style: theme.textTheme.bodyMedium),
                ),
                Expanded(
                  child: ProgressBar(
                    value: e.value / maxV,
                    color: muscleColor(e.key),
                    height: 10,
                  ),
                ),
                SizedBox(
                  width: 44,
                  child: Text(
                    formatNumber(e.value, decimals: 1),
                    textAlign: TextAlign.right,
                    style: theme.textTheme.labelLarge,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
