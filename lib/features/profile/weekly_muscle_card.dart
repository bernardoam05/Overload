import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/format.dart';
import '../../domain/enums.dart';
import '../../domain/progression.dart';
import '../../domain/stats.dart';
import '../../widgets/common.dart';

/// Muscles shown in the weekly breakdown (cardio and full body excluded).
final weeklyMuscles = [
  for (final m in Muscle.values)
    if (m != Muscle.cardio && m != Muscle.fullBody) m,
];

/// Working sets per muscle this week (or last week) against the weekly
/// target, so under-trained muscles stand out.
class WeeklyMuscleCard extends ConsumerStatefulWidget {
  const WeeklyMuscleCard({super.key});

  @override
  ConsumerState<WeeklyMuscleCard> createState() => _WeeklyMuscleCardState();
}

class _WeeklyMuscleCardState extends ConsumerState<WeeklyMuscleCard> {
  int _weeksAgo = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = theme.colorScheme;
    final history = ref.watch(historyListProvider);
    final library = ref.watch(libraryProvider);
    final target = ref.watch(currentProfileProvider).weeklySetTarget;

    final thisWeek = weekStart(DateTime.now());
    final start = DateTime(
      thisWeek.year,
      thisWeek.month,
      thisWeek.day - 7 * _weeksAgo,
    );
    final end = DateTime(start.year, start.month, start.day + 7);
    final data = setsPerMuscle(history, library, since: start, until: end);
    final values = {for (final m in weeklyMuscles) m: data[m] ?? 0.0};
    final top = values.values.fold(0.0, (a, b) => a > b ? a : b);
    final scale = [top, target * 1.5, 1.0].reduce((a, b) => a > b ? a : b);
    final onTarget = target == 0
        ? 0
        : values.values.where((v) => v >= target).length;
    final daysLeft = _weeksAgo == 0 ? 7 - DateTime.now().weekday : 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Esta semana')),
                ButtonSegment(value: 1, label: Text('Semana passada')),
              ],
              selected: {_weeksAgo},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _weeksAgo = s.first),
            ),
            const SizedBox(height: 12),
            if (target > 0)
              Text(
                '$onTarget de ${weeklyMuscles.length} músculos no alvo '
                '($target séries)'
                '${daysLeft > 0 ? ' · faltam $daysLeft ${daysLeft == 1 ? 'dia' : 'dias'}' : ''}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: c.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: 8),
            for (final m in weeklyMuscles)
              _MuscleRow(
                muscle: m,
                value: values[m]!,
                target: target,
                scale: scale,
              ),
            const SizedBox(height: 4),
            Text(
              'Séries efetivas (sem aquecimentos). Músculos secundários contam '
              'meia série. O alvo muda-se nas Definições.',
              style: theme.textTheme.labelSmall?.copyWith(
                color: c.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MuscleRow extends StatelessWidget {
  const _MuscleRow({
    required this.muscle,
    required this.value,
    required this.target,
    required this.scale,
  });

  final Muscle muscle;
  final double value;
  final int target;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = theme.colorScheme;
    final hit = target > 0 && value >= target;
    final color = target == 0
        ? muscleColor(muscle)
        : hit
        ? Brand.success
        : value == 0
        ? c.outlineVariant
        : Brand.amber;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(muscle.label, style: theme.textTheme.bodyMedium),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) {
                final markerX = box.maxWidth * (target / scale).clamp(0, 1);
                return SizedBox(
                  height: 14,
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      Container(
                        height: 10,
                        decoration: BoxDecoration(
                          color: c.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: (value / scale).clamp(0, 1),
                        child: Container(
                          height: 10,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      if (target > 0)
                        Positioned(
                          left: (markerX - 1).clamp(0, box.maxWidth - 2),
                          child: Container(
                            width: 2,
                            height: 14,
                            color: c.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          SizedBox(
            width: 56,
            child: Text(
              target > 0
                  ? '${formatNumber(value, decimals: 1)}/$target'
                  : formatNumber(value, decimals: 1),
              textAlign: TextAlign.right,
              style: theme.textTheme.labelLarge?.copyWith(
                color: hit ? Brand.success : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
