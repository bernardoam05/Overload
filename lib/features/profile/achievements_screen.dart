import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/format.dart';
import '../../domain/achievements.dart';
import '../../widgets/common.dart';

IconData achievementIcon(AchievementCategory c) => switch (c) {
  AchievementCategory.workouts => Icons.fitness_center,
  AchievementCategory.streak => Icons.local_fire_department_rounded,
  AchievementCategory.records => Icons.workspace_premium_rounded,
  AchievementCategory.volume => Icons.scale_rounded,
  AchievementCategory.session => Icons.timer_rounded,
  AchievementCategory.ranks => Icons.military_tech_rounded,
  AchievementCategory.variety => Icons.explore_rounded,
  AchievementCategory.level => Icons.trending_up_rounded,
};

Color achievementColor(AchievementCategory c) => switch (c) {
  AchievementCategory.workouts => Brand.ember,
  AchievementCategory.streak => const Color(0xFFFF4D4D),
  AchievementCategory.records => Brand.amber,
  AchievementCategory.volume => const Color(0xFF4F9DFF),
  AchievementCategory.session => const Color(0xFF2EC4B6),
  AchievementCategory.ranks => const Color(0xFFB18CFF),
  AchievementCategory.variety => Brand.success,
  AchievementCategory.level => const Color(0xFFF6C744),
};

class AchievementMedal extends StatelessWidget {
  const AchievementMedal({super.key, required this.progress, this.size = 56});

  final AchievementProgress progress;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = achievementColor(progress.achievement.category);
    final on = progress.unlocked;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: on
            ? LinearGradient(
                colors: [
                  Color.lerp(color, Colors.white, 0.25)!,
                  Color.lerp(color, Colors.black, 0.35)!,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: on ? null : theme.colorScheme.surfaceContainerHighest,
        boxShadow: on
            ? [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 12)]
            : null,
      ),
      child: Icon(
        on
            ? achievementIcon(progress.achievement.category)
            : Icons.lock_outline_rounded,
        size: size * 0.48,
        color: on ? Colors.white : theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final list = ref.watch(achievementsProvider);
    final unlocked = list.where((a) => a.unlocked).length;
    final sorted = [...list]
      ..sort((a, b) {
        if (a.unlocked != b.unlocked) return a.unlocked ? -1 : 1;
        return b.fraction.compareTo(a.fraction);
      });

    return Scaffold(
      appBar: AppBar(title: const Text('Conquistas')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$unlocked de ${list.length} desbloqueadas',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  ProgressBar(
                    value: list.isEmpty ? 0 : unlocked / list.length,
                    color: Brand.amber,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final a in sorted) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    AchievementMedal(progress: a),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.achievement.title,
                            style: theme.textTheme.titleSmall,
                          ),
                          Text(
                            a.achievement.description,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (!a.unlocked) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: ProgressBar(
                                    value: a.fraction,
                                    color: achievementColor(
                                      a.achievement.category,
                                    ),
                                    height: 6,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${formatNumber(a.value.clamp(0, a.achievement.target), decimals: 0)}/${formatNumber(a.achievement.target, decimals: 0)}',
                                  style: theme.textTheme.labelSmall,
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}
