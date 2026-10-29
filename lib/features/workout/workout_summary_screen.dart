import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/format.dart';
import '../../domain/enums.dart';
import '../../domain/records.dart';
import '../../widgets/common.dart';
import '../../widgets/rank_badge.dart';
import '../profile/achievements_screen.dart';
import 'active_workout_controller.dart';

String formatRecordValue(
  PersonalRecord r,
  ExerciseKind kind,
  WeightUnit unit,
) => switch (r.type) {
  RecordType.e1rm || RecordType.weight => formatWeight(r.value, unit),
  RecordType.volume => '${formatWeight(r.set.weightKg, unit)} × ${r.set.reps}',
  RecordType.reps => '${r.value.round()} reps',
  RecordType.duration => formatSeconds(r.value.round()),
};

class WorkoutSummaryScreen extends ConsumerWidget {
  const WorkoutSummaryScreen({super.key, required this.summary});

  final WorkoutSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final unit = ref.watch(currentProfileProvider).unit;
    final library = ref.watch(libraryProvider);
    final r = summary.record;
    final leveledUp = summary.levelAfter.level > summary.levelBefore.level;
    final newAchievements = [
      for (final a in ref.watch(achievementsProvider))
        if (a.unlocked &&
            !summary.achievementsBefore.contains(a.achievement.id))
          a,
    ];

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          children: [
            Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.6, end: 1),
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut,
                builder: (_, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    gradient: Brand.emberGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Brand.ember.withValues(alpha: 0.5),
                        blurRadius: 32,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.emoji_events_rounded,
                    size: 52,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Treino concluído!',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: 4),
            Text(
              r.name,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        value: formatDuration(r.duration),
                        label: 'Duração',
                        icon: Icons.timer_outlined,
                      ),
                    ),
                    Expanded(
                      child: StatTile(
                        value: formatVolume(summary.volumeKg, unit),
                        label: 'Volume',
                        icon: Icons.fitness_center_rounded,
                      ),
                    ),
                    Expanded(
                      child: StatTile(
                        value: '${r.setCount}',
                        label: 'Séries',
                        icon: Icons.repeat_rounded,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '+${summary.xp} XP',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: theme.colorScheme.secondary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Nível ${summary.levelAfter.level}',
                          style: theme.textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TweenAnimationBuilder<double>(
                      tween: Tween(
                        begin: leveledUp ? 0 : summary.levelBefore.progress,
                        end: summary.levelAfter.progress,
                      ),
                      duration: const Duration(milliseconds: 1200),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, _) => ProgressBar(
                        value: v,
                        color: theme.colorScheme.secondary,
                        height: 10,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      leveledUp
                          ? 'Subiste para o nível ${summary.levelAfter.level}! 🔥'
                          : '${summary.levelAfter.xpForLevel - summary.levelAfter.xpIntoLevel} XP para o nível ${summary.levelAfter.level + 1}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (summary.rankChanges.isNotEmpty) ...[
              const SectionHeader('Progresso de rank'),
              Card(
                child: Column(
                  children: [
                    for (final c in summary.rankChanges)
                      ListTile(
                        leading: RankBadge(standing: c.after, size: 40),
                        title: Text(c.group.label),
                        subtitle: Text(
                          c.before.label == c.after.label
                              ? '${c.after.label} · +${((c.after.divisionProgress - c.before.divisionProgress) * 100).round()}%'
                              : '${c.before.label} → ${c.after.label}',
                        ),
                        trailing: c.before.label == c.after.label
                            ? null
                            : Icon(
                                Icons.trending_up_rounded,
                                color: Brand.tierColor(c.after.tier),
                              ),
                      ),
                  ],
                ),
              ),
            ],
            if (!summary.edited && newAchievements.isNotEmpty) ...[
              SectionHeader(
                'Conquistas desbloqueadas (${newAchievements.length})',
              ),
              Card(
                child: Column(
                  children: [
                    for (final a in newAchievements)
                      ListTile(
                        leading: AchievementMedal(progress: a, size: 40),
                        title: Text(a.achievement.title),
                        subtitle: Text(a.achievement.description),
                      ),
                  ],
                ),
              ),
            ],
            if (summary.records.isNotEmpty) ...[
              SectionHeader('Recordes pessoais (${summary.records.length})'),
              Card(
                child: Column(
                  children: [
                    for (final pr in summary.records)
                      ListTile(
                        leading: const Icon(
                          Icons.workspace_premium_rounded,
                          color: Brand.amber,
                        ),
                        title: Text(
                          library[pr.exerciseId]?.name ?? 'Exercício',
                        ),
                        subtitle: Text(pr.type.label),
                        trailing: Text(
                          formatRecordValue(
                            pr,
                            library[pr.exerciseId]?.kind ??
                                ExerciseKind.weighted,
                            unit,
                          ),
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.go('/home'),
              child: const Text('Concluir'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () =>
                  context.pushReplacement('/workouts/${summary.workoutId}'),
              child: const Text('Ver detalhes do treino'),
            ),
          ],
        ),
      ),
    );
  }
}
