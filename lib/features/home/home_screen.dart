import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/format.dart';
import '../../domain/progression.dart';
import '../../widgets/common.dart';
import '../../widgets/rank_badge.dart';
import '../history/workout_tile.dart';
import '../workout/active_workout_controller.dart';
import '../workout/start_workout.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 6) return 'Boa noite';
    if (h < 13) return 'Bom dia';
    if (h < 20) return 'Boa tarde';
    return 'Boa noite';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profile = ref.watch(currentProfileProvider);
    final history = ref.watch(historyListProvider);
    final level = ref.watch(levelProvider);
    final active = ref.watch(activeWorkoutProvider);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        capitalize(formatDateLong(DateTime.now())),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        profile.name.isEmpty
                            ? _greeting()
                            : '${_greeting()}, ${profile.name}',
                        style: theme.textTheme.headlineSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                _LevelRing(level: level),
              ],
            ),
            const SizedBox(height: 20),
            const _StreakCard(),
            const SizedBox(height: 12),
            const _RankCard(),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => active != null
                  ? context.push('/workout')
                  : startWorkout(context, ref, (c) => c.startEmpty()),
              icon: Icon(
                active != null ? Icons.play_arrow_rounded : Icons.add_rounded,
              ),
              label: Text(active != null ? 'Retomar treino' : 'Começar treino'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => context.go('/train'),
              icon: const Icon(Icons.view_list_rounded),
              label: const Text('Escolher rotina'),
            ),
            SectionHeader(
              'Treinos recentes',
              action: history.isEmpty ? null : 'Ver todos',
              onAction: () => context.go('/history'),
            ),
            if (history.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: EmptyState(
                    icon: Icons.local_fire_department_outlined,
                    title: 'O teu primeiro treino espera-te',
                    message:
                        'Cada série conta para o teu nível e para os teus ranks.',
                  ),
                ),
              )
            else
              for (final w in history.take(3)) ...[
                WorkoutTile(workout: w),
                const SizedBox(height: 12),
              ],
          ],
        ),
      ),
    );
  }
}

class _LevelRing extends StatelessWidget {
  const _LevelRing({required this.level});

  final LevelInfo level;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: () => context.go('/profile'),
      child: SizedBox.square(
        dimension: 56,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.expand(
              child: CircularProgressIndicator(
                value: level.progress,
                strokeWidth: 5,
                strokeCap: StrokeCap.round,
                color: theme.colorScheme.secondary,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'NÍV',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 9,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  '${level.level}',
                  style: theme.textTheme.titleMedium?.copyWith(height: 1),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StreakCard extends ConsumerWidget {
  const _StreakCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final streak = ref.watch(streakProvider);
    final monday = weekStart(DateTime.now());
    final today = dayOf(DateTime.now());
    const letters = ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ShaderMask(
                  shaderCallback: (r) => Brand.emberGradient.createShader(r),
                  child: const Icon(
                    Icons.local_fire_department_rounded,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${streak.current} ${streak.current == 1 ? 'semana' : 'semanas'}',
                        style: theme.textTheme.headlineSmall,
                      ),
                      Text(
                        streak.goalMetThisWeek
                            ? 'Objetivo da semana cumprido!'
                            : 'Faltam ${streak.goal - streak.daysThisWeek} ${streak.goal - streak.daysThisWeek == 1 ? 'treino' : 'treinos'} esta semana',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${streak.daysThisWeek}/${streak.goal}',
                  style: theme.textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 0; i < 7; i++)
                  Builder(
                    builder: (context) {
                      final day = DateTime(
                        monday.year,
                        monday.month,
                        monday.day + i,
                      );
                      final trained = streak.trainedDays.contains(day);
                      final isToday = day == today;
                      return Column(
                        children: [
                          Text(
                            letters[i],
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: isToday
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              gradient: trained ? Brand.emberGradient : null,
                              color: trained
                                  ? null
                                  : theme.colorScheme.surfaceContainerHighest,
                              shape: BoxShape.circle,
                              border: isToday && !trained
                                  ? Border.all(
                                      color: theme.colorScheme.primary,
                                      width: 2,
                                    )
                                  : null,
                            ),
                            child: trained
                                ? const Icon(
                                    Icons.check_rounded,
                                    size: 18,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                        ],
                      );
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RankCard extends ConsumerWidget {
  const _RankCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ranks = ref.watch(ranksProvider);
    final overall = ranks.overall;
    final color = Brand.tierColor(overall.tier);

    return Card(
      child: InkWell(
        onTap: () => context.go('/ranks'),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withValues(alpha: 0.18), Colors.transparent],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              RankBadge(standing: overall, size: 64),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rank geral',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      overall.label,
                      style: theme.textTheme.titleLarge?.copyWith(color: color),
                    ),
                    const SizedBox(height: 8),
                    ProgressBar(
                      value: overall.divisionProgress,
                      color: color,
                      height: 6,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      overall.isMaxTier
                          ? 'Topo alcançado'
                          : 'Próximo: ${overall.nextLabel}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
