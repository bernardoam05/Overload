import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/format.dart';
import '../../domain/enums.dart';
import '../../widgets/common.dart';
import 'active_workout_controller.dart';
import 'exercise_card.dart';
import 'finish_sheet.dart';
import 'workout_tips.dart';

class ActiveWorkoutScreen extends ConsumerStatefulWidget {
  const ActiveWorkoutScreen({super.key});

  @override
  ConsumerState<ActiveWorkoutScreen> createState() =>
      _ActiveWorkoutScreenState();
}

/// The parts of the workout the screen itself shows; set edits don't
/// change it, so the screen doesn't rebuild while typing.
typedef _Shape = ({
  bool editing,
  String name,
  String notes,
  DateTime startedAt,
  String ids,
  DateTime? restEndsAt,
  int restTotal,
});

class _ActiveWorkoutScreenState extends ConsumerState<ActiveWorkoutScreen> {
  bool _finishing = false;

  Future<void> _addExercises() async {
    final ids = await context.push<List<int>>('/exercises/pick');
    if (ids != null && ids.isNotEmpty) {
      ref.read(activeWorkoutProvider.notifier).addExercises(ids);
    }
  }

  Future<void> _finish() async {
    final w = ref.read(activeWorkoutProvider);
    if (w == null) return;
    final library = ref.read(libraryProvider);
    final pending = pendingSets(w, library);
    if (w.doneSets == 0 && pending.filled == 0) {
      showMessage(context, 'Completa pelo menos uma série antes de terminar.');
      return;
    }
    final choice = await showFinishSheet(
      context,
      workout: w,
      library: library,
      unit: ref.read(currentProfileProvider).unit,
    );
    if (choice == null || !mounted) return;
    if (choice == FinishChoice.completeFilledAndFinish) {
      ref.read(activeWorkoutProvider.notifier).completeFilledSets({
        for (final e in library.values)
          if (e.kind != ExerciseKind.weighted) e.id,
      });
    }
    setState(() => _finishing = true);
    try {
      final summary = await ref.read(activeWorkoutProvider.notifier).finish();
      if (!mounted) return;
      if (summary.edited) {
        context.pop();
        showMessage(context, 'Treino atualizado.');
      } else {
        context.pushReplacement('/summary', extra: summary);
      }
    } on FinishException catch (e) {
      if (mounted) showMessage(context, e.message);
    } finally {
      if (mounted) setState(() => _finishing = false);
    }
  }

  Future<void> _cancel() async {
    final w = ref.read(activeWorkoutProvider);
    if (w == null) return;
    final ok = await confirm(
      context,
      title: w.isEditing ? 'Descartar alterações?' : 'Cancelar treino?',
      message: w.isEditing
          ? 'O treino original fica como estava.'
          : 'Todas as séries deste treino serão apagadas.',
      confirmLabel: w.isEditing ? 'Descartar' : 'Cancelar treino',
      destructive: true,
    );
    if (!ok || !mounted) return;
    ref.read(activeWorkoutProvider.notifier).discard();
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final shape = ref.watch(
      activeWorkoutProvider.select<_Shape?>(
        (w) => w == null
            ? null
            : (
                editing: w.isEditing,
                name: w.name,
                notes: w.notes,
                startedAt: w.startedAt,
                ids: w.exercises.map((e) => e.id).join(','),
                restEndsAt: w.restEndsAt,
                restTotal: w.restTotalSeconds,
              ),
      ),
    );
    final theme = Theme.of(context);
    if (shape == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.fitness_center,
          title: 'Nenhum treino a decorrer',
        ),
      );
    }
    final controller = ref.read(activeWorkoutProvider.notifier);
    final ids = shape.ids.isEmpty ? const <String>[] : shape.ids.split(',');
    final showTips =
        !ref.watch(currentProfileProvider.select((p) => p.seenWorkoutTips)) &&
        ids.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Minimizar',
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          onPressed: () => context.pop(),
        ),
        title: shape.editing
            ? const Text('Editar treino')
            : _ElapsedClock(startedAt: shape.startedAt),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 40),
                backgroundColor: Brand.success,
                foregroundColor: Colors.black,
              ),
              onPressed: _finishing ? null : _finish,
              child: Text(shape.editing ? 'Guardar' : 'Terminar'),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Mais opções',
            onSelected: (v) {
              if (v == 'cancel') _cancel();
              if (v == 'tips') showWorkoutTips(context);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'tips',
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline_rounded),
                    SizedBox(width: 12),
                    Text('Dicas e atalhos'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'cancel',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline_rounded,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      shape.editing
                          ? 'Descartar alterações'
                          : 'Cancelar treino',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 140),
            children: [
              _WorkoutHeader(
                name: shape.name,
                notes: shape.notes,
                startedAt: shape.startedAt,
              ),
              const SizedBox(height: 12),
              if (showTips) ...[
                const WorkoutTipsCard(),
                const SizedBox(height: 12),
              ],
              for (final (i, id) in ids.indexed) ...[
                ActiveExerciseCard(
                  key: ValueKey(id),
                  entryId: id,
                  index: i,
                  total: ids.length,
                ),
                const SizedBox(height: 12),
              ],
              if (ids.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: EmptyState(
                    icon: Icons.playlist_add_rounded,
                    title: 'Começa por adicionar exercícios',
                    message:
                        'As tuas séries anteriores aparecem como referência.',
                  ),
                ),
              FilledButton.tonalIcon(
                onPressed: _addExercises,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Adicionar exercícios'),
              ),
              const SizedBox(height: 12),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
                onPressed: _cancel,
                child: Text(
                  shape.editing ? 'Descartar alterações' : 'Cancelar treino',
                ),
              ),
            ],
          ),
          if (shape.restEndsAt != null &&
              shape.restEndsAt!.isAfter(DateTime.now()))
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: SafeArea(
                child: _RestTimerBar(
                  key: ValueKey(shape.restEndsAt),
                  endsAt: shape.restEndsAt!,
                  total: shape.restTotal,
                  onAdjust: controller.adjustRest,
                  onSkip: controller.skipRest,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WorkoutHeader extends ConsumerWidget {
  const _WorkoutHeader({
    required this.name,
    required this.notes,
    required this.startedAt,
  });

  final String name;
  final String notes;
  final DateTime startedAt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final controller = ref.read(activeWorkoutProvider.notifier);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () async {
              final value = await promptText(
                context,
                title: 'Nome do treino',
                initial: name,
              );
              if (value != null) controller.rename(value);
            },
            child: Row(
              children: [
                Flexible(
                  child: Text(name, style: theme.textTheme.headlineSmall),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${capitalize(formatDate(startedAt))} · ${formatTime(startedAt)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          InkWell(
            onTap: () async {
              final value = await promptText(
                context,
                title: 'Notas do treino',
                initial: notes,
                maxLines: 4,
                maxLength: 1000,
              );
              if (value != null) controller.setNotes(value.trim());
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                notes.isEmpty ? '+ Adicionar notas' : notes,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: notes.isEmpty
                      ? theme.colorScheme.onSurfaceVariant
                      : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ticking clock for the app bar, isolated so the rest of the screen does
/// not rebuild every second.
class _ElapsedClock extends StatefulWidget {
  const _ElapsedClock({required this.startedAt});

  final DateTime startedAt;

  @override
  State<_ElapsedClock> createState() => _ElapsedClockState();
}

class _ElapsedClockState extends State<_ElapsedClock> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text(
    formatClock(DateTime.now().difference(widget.startedAt)),
    style: Theme.of(context).textTheme.titleLarge?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    ),
  );
}

class _RestTimerBar extends StatefulWidget {
  const _RestTimerBar({
    super.key,
    required this.endsAt,
    required this.total,
    required this.onAdjust,
    required this.onSkip,
  });

  final DateTime endsAt;
  final int total;
  final ValueChanged<int> onAdjust;
  final VoidCallback onSkip;

  @override
  State<_RestTimerBar> createState() => _RestTimerBarState();
}

class _RestTimerBarState extends State<_RestTimerBar> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  DateTime get endsAt => widget.endsAt;
  int get total => widget.total;
  ValueChanged<int> get onAdjust => widget.onAdjust;
  VoidCallback get onSkip => widget.onSkip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remaining = endsAt.difference(DateTime.now());
    final fraction = total == 0
        ? 0.0
        : remaining.inMilliseconds / (total * 1000);
    return Material(
      elevation: 12,
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(
            value: fraction.clamp(0, 1),
            minHeight: 4,
            color: theme.colorScheme.secondary,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
            child: Row(
              children: [
                Icon(Icons.timer_outlined, color: theme.colorScheme.secondary),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Descanso',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      formatClock(
                        remaining + const Duration(milliseconds: 999),
                      ),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => onAdjust(-15),
                  child: const Text('−15'),
                ),
                TextButton(
                  onPressed: () => onAdjust(15),
                  child: const Text('+15'),
                ),
                FilledButton.tonal(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                  onPressed: onSkip,
                  child: const Text('Saltar'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
