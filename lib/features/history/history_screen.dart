import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/format.dart';
import '../../domain/models.dart';
import '../../domain/progression.dart';
import '../../widgets/common.dart';
import 'workout_tile.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  void _shift(int months) =>
      setState(() => _month = DateTime(_month.year, _month.month + months));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final history = ref.watch(historyListProvider);
    final library = ref.watch(libraryProvider);
    final unit = ref.watch(currentProfileProvider).unit;
    final inMonth = [
      for (final w in history)
        if (w.startedAt.year == _month.year &&
            w.startedAt.month == _month.month)
          w,
    ];
    final now = DateTime.now();
    final isCurrentMonth = _month.year == now.year && _month.month == now.month;

    return Scaffold(
      appBar: AppBar(title: const Text('Histórico')),
      body: history.isEmpty
          ? const EmptyState(
              icon: Icons.calendar_month_outlined,
              title: 'Ainda não tens treinos',
              message:
                  'Os treinos terminados aparecem aqui, com calendário e estatísticas.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => _shift(-1),
                              icon: const Icon(Icons.chevron_left_rounded),
                            ),
                            Expanded(
                              child: Text(
                                capitalize(formatMonth(_month)),
                                textAlign: TextAlign.center,
                                style: theme.textTheme.titleMedium,
                              ),
                            ),
                            IconButton(
                              onPressed: isCurrentMonth
                                  ? null
                                  : () => _shift(1),
                              icon: const Icon(Icons.chevron_right_rounded),
                            ),
                          ],
                        ),
                        _MonthGrid(month: _month, workouts: inMonth),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: StatTile(
                                  value: '${inMonth.length}',
                                  label: 'Treinos',
                                ),
                              ),
                              Expanded(
                                child: StatTile(
                                  value: formatDuration(
                                    inMonth.fold(
                                      Duration.zero,
                                      (s, w) => s + w.duration,
                                    ),
                                  ),
                                  label: 'Tempo',
                                ),
                              ),
                              Expanded(
                                child: StatTile(
                                  value: formatVolume(
                                    inMonth.fold(
                                      0.0,
                                      (s, w) => s + w.volume(library),
                                    ),
                                    unit,
                                  ),
                                  label: 'Volume',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (inMonth.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Sem treinos neste mês.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                for (final w in inMonth) ...[
                  WorkoutTile(workout: w),
                  const SizedBox(height: 12),
                ],
              ],
            ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.month, required this.workouts});

  final DateTime month;
  final List<WorkoutRecord> workouts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final byDay = <DateTime, List<WorkoutRecord>>{};
    for (final w in workouts) {
      byDay.putIfAbsent(dayOf(w.startedAt), () => []).add(w);
    }
    final first = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = first.weekday - 1;
    final today = dayOf(DateTime.now());
    const letters = ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'];
    final cells = leading + daysInMonth;
    final rows = (cells / 7).ceil();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Row(
            children: [
              for (final l in letters)
                Expanded(
                  child: Center(
                    child: Text(
                      l,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          for (var r = 0; r < rows; r++)
            Row(
              children: [
                for (var c = 0; c < 7; c++)
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final dayNumber = r * 7 + c - leading + 1;
                        if (dayNumber < 1 || dayNumber > daysInMonth) {
                          return const SizedBox(height: 40);
                        }
                        final day = DateTime(
                          month.year,
                          month.month,
                          dayNumber,
                        );
                        final list = byDay[day];
                        final trained = list != null;
                        return Padding(
                          padding: const EdgeInsets.all(3),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: trained
                                ? () =>
                                      context.push('/workouts/${list.first.id}')
                                : null,
                            child: Container(
                              height: 34,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                gradient: trained ? Brand.emberGradient : null,
                                borderRadius: BorderRadius.circular(12),
                                border: day == today && !trained
                                    ? Border.all(
                                        color: theme.colorScheme.primary,
                                        width: 1.5,
                                      )
                                    : null,
                              ),
                              child: Text(
                                '$dayNumber',
                                style: TextStyle(
                                  fontWeight: trained
                                      ? FontWeight.w900
                                      : FontWeight.w600,
                                  color: trained
                                      ? Colors.white
                                      : theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
