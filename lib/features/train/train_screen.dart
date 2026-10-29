import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/format.dart';
import '../../data/repositories/routine_repository.dart';
import '../../widgets/common.dart';
import '../workout/active_workout_controller.dart';
import '../workout/start_workout.dart';
import 'routine_editor_screen.dart';

class TrainScreen extends ConsumerWidget {
  const TrainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final routines = ref.watch(routinesProvider);
    final active = ref.watch(activeWorkoutProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Treinar'),
        actions: [
          IconButton(
            tooltip: 'Exercícios',
            icon: const Icon(Icons.menu_book_outlined),
            onPressed: () => context.push('/exercises'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: Brand.emberGradient,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Brand.ember.withValues(alpha: 0.25),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.bolt_rounded, color: Colors.white, size: 32),
                const SizedBox(height: 8),
                Text(
                  active != null ? 'Treino a decorrer' : 'Treino livre',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  active != null
                      ? active.name
                      : 'Começa vazio e adiciona exercícios à medida que treinas.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    minimumSize: const Size.fromHeight(50),
                  ),
                  onPressed: () => active != null
                      ? context.push('/workout')
                      : startWorkout(context, ref, (c) => c.startEmpty()),
                  child: Text(
                    active != null ? 'Retomar' : 'Começar treino vazio',
                  ),
                ),
              ],
            ),
          ),
          SectionHeader(
            'As tuas rotinas',
            action: 'Nova',
            onAction: () => context.push('/routines/new'),
          ),
          routines.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Erro: $e'),
            data: (list) => list.isEmpty
                ? EmptyState(
                    icon: Icons.view_list_rounded,
                    title: 'Sem rotinas',
                    message: 'Cria rotinas para começar treinos com um toque.',
                    action: FilledButton.tonal(
                      onPressed: () => context.push('/routines/new'),
                      child: const Text('Criar rotina'),
                    ),
                  )
                : Column(
                    children: [
                      for (final r in list) ...[
                        _RoutineCard(routine: r),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _RoutineCard extends ConsumerWidget {
  const _RoutineCard({required this.routine});

  final RoutineWithItems routine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final library = ref.watch(libraryProvider);
    final names = [
      for (final i in routine.items)
        if (library[i.exerciseId] != null)
          '${i.sets}× ${library[i.exerciseId]!.name}',
    ];
    final last = routine.routine.lastUsedAt;

    return Card(
      child: InkWell(
        onTap: () => context.push('/routines/${routine.routine.id}'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      routine.routine.name,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_horiz_rounded),
                    onSelected: (v) async {
                      final repo = ref.read(routineRepositoryProvider);
                      switch (v) {
                        case 'edit':
                          context.push('/routines/${routine.routine.id}');
                        case 'duplicate':
                          context.push(
                            '/routines/new',
                            extra: RoutineTemplate(
                              '${routine.routine.name} (cópia)',
                              routine.items,
                            ),
                          );
                        case 'delete':
                          if (await confirm(
                            context,
                            title: 'Apagar "${routine.routine.name}"?',
                            confirmLabel: 'Apagar',
                            destructive: true,
                          )) {
                            await repo.delete(routine.routine.id);
                          }
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Editar')),
                      PopupMenuItem(
                        value: 'duplicate',
                        child: Text('Duplicar'),
                      ),
                      PopupMenuItem(value: 'delete', child: Text('Apagar')),
                    ],
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  names.isEmpty ? 'Sem exercícios' : names.join('\n'),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      last == null
                          ? 'Nunca feita'
                          : 'Última vez: ${formatRelativeDay(last).toLowerCase()}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 42),
                    ),
                    onPressed: routine.items.isEmpty
                        ? null
                        : () => startWorkout(
                            context,
                            ref,
                            (c) => c.startFromRoutine(routine),
                          ),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Começar'),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
