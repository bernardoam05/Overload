import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/repositories/routine_repository.dart';
import '../../domain/enums.dart';
import '../../domain/exercise.dart';
import '../../widgets/common.dart';

/// One exercise of the routine being edited: planned sets, target reps (and
/// how they descend), superset link and pinned note.
class RoutineItemCard extends StatelessWidget {
  const RoutineItemCard({
    super.key,
    required this.index,
    required this.rowKey,
    required this.item,
    required this.exercise,
    required this.isLast,
    required this.linkedFromPrevious,
    required this.onChanged,
    required this.onNotes,
    required this.onRemove,
  });

  final int index;
  final int rowKey;
  final RoutineItem item;
  final Exercise? exercise;
  final bool isLast;

  /// The previous exercise is linked to this one in a superset.
  final bool linkedFromPrevious;
  final ValueChanged<RoutineItem> onChanged;

  /// Note edits don't rebuild the list (the field keeps its own text).
  final ValueChanged<String> onNotes;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ex = exercise;
    final isTime = ex?.kind == ExerciseKind.duration;
    final linked = item.supersetNext && !isLast;
    final inSuperset = linked || linkedFromPrevious;
    final mainSets = item.targets.whereType<int>().length;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: inSuperset
            ? BorderSide(color: theme.colorScheme.secondary, width: 1.5)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 12),
        child: Column(
          children: [
            Row(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.drag_indicator_rounded),
                  ),
                ),
                const SizedBox(width: 6),
                if (ex != null) MuscleAvatar(ex.primaryMuscle, size: 34),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ex?.name ?? 'Exercício removido',
                        style: theme.textTheme.titleSmall,
                      ),
                      if (ex?.loadLabel case final load?)
                        Text(
                          load,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.tertiary,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: onRemove,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: SetPlanEditor(
                types: item.setTypes,
                onChanged: (types) => onChanged(item.copyWith(setTypes: types)),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _Stepper(
                label: isTime
                    ? 'Segundos por série'
                    : item.repStep > 0
                    ? 'Reps alvo na 1.ª série'
                    : 'Reps alvo por série',
                value: item.reps,
                min: 1,
                max: isTime ? 900 : 100,
                step: isTime ? 15 : 1,
                onChanged: (v) => onChanged(item.copyWith(reps: v)),
              ),
            ),
            if (!isTime && mainSets > 1) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: RepStepPicker(
                  item: item,
                  onChanged: (step) => onChanged(item.copyWith(repStep: step)),
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 8, 8, 0),
              child: TextFormField(
                key: ValueKey('note-$rowKey'),
                initialValue: item.notes,
                minLines: 1,
                maxLines: 3,
                maxLength: 500,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  isDense: true,
                  counterText: '',
                  prefixIcon: Icon(Icons.push_pin_outlined, size: 18),
                  hintText: 'Nota fixa (aparece em todos os treinos)',
                ),
                onChanged: onNotes,
              ),
            ),
            if (!isLast)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () =>
                      onChanged(item.copyWith(supersetNext: !linked)),
                  icon: Icon(
                    linked ? Icons.link_off_rounded : Icons.link_rounded,
                    size: 18,
                  ),
                  label: Text(
                    linked
                        ? 'Em supersérie com o seguinte · separar'
                        : 'Supersérie com o seguinte',
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: linked
                        ? theme.colorScheme.secondary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// "Iguais / −1 / −2 / −3" per working set, with a preview of the targets.
class RepStepPicker extends StatelessWidget {
  const RepStepPicker({super.key, required this.item, required this.onChanged});

  final RoutineItem item;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Reps por série',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            Text(
              describeTargets(item),
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<int>(
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: [
              const ButtonSegment(value: 0, label: Text('Iguais')),
              for (var s = 1; s <= RoutineItem.maxRepStep; s++)
                ButtonSegment(value: s, label: Text('−$s')),
            ],
            selected: {item.repStep},
            onSelectionChanged: (v) => onChanged(v.first),
          ),
        ),
      ],
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.step = 1,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.remove_rounded),
            onPressed: value - step >= min
                ? () => onChanged(value - step)
                : null,
          ),
          Expanded(
            child: Column(
              children: [
                Text('$value', style: theme.textTheme.titleMedium),
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add_rounded),
            onPressed: value + step <= max
                ? () => onChanged(value + step)
                : null,
          ),
        ],
      ),
    );
  }
}

/// Planned sets of a routine exercise as chips (A = aquecimento, numbers for
/// working sets, F = até à falha, D = drop). Tap a chip to change its type
/// or remove it.
class SetPlanEditor extends StatelessWidget {
  const SetPlanEditor({
    super.key,
    required this.types,
    required this.onChanged,
  });

  final List<SetType> types;
  final ValueChanged<List<SetType>> onChanged;

  bool get _full => types.length >= RoutineItem.maxSets;

  void _insert(SetType type) {
    if (_full) return;
    final list = [...types];
    switch (type) {
      case SetType.warmup:
        list.insert(list.lastIndexWhere((t) => t == SetType.warmup) + 1, type);
      case SetType.drop:
        list.add(type);
      case SetType.normal || SetType.failure:
        // Before trailing drops, which follow the last working set.
        var at = list.length;
        while (at > 0 && list[at - 1] == SetType.drop) {
          at--;
        }
        list.insert(at, type);
    }
    onChanged(list);
  }

  Future<void> _edit(BuildContext context, int i) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final t in SetType.values)
              ListTile(
                leading: _SetChipLabel(type: t, number: null),
                title: Text(t.label),
                trailing: types[i] == t ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(context, t.name),
              ),
            if (types.length > 1)
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: const Text('Remover série'),
                onTap: () => Navigator.pop(context, 'remove'),
              ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    if (choice == 'remove') {
      _remove(i);
    } else {
      onChanged([...types]..[i] = SetType.values.byName(choice));
    }
  }

  void _remove(int i) => onChanged([...types]..removeAt(i));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    var working = 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final (i, t) in types.indexed)
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _edit(context, i),
                onLongPress: types.length > 1 ? () => _remove(i) : null,
                child: _SetChipLabel(
                  type: t,
                  number: t == SetType.warmup ? null : ++working,
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          describeSetTypes(types),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Wrap(
          spacing: 4,
          children: [
            TextButton(
              onPressed: _full ? null : () => _insert(SetType.normal),
              child: const Text('+ Série'),
            ),
            TextButton(
              onPressed: _full ? null : () => _insert(SetType.warmup),
              child: const Text('+ Aquecimento'),
            ),
            TextButton(
              onPressed: _full ? null : () => _insert(SetType.drop),
              child: const Text('+ Drop'),
            ),
          ],
        ),
      ],
    );
  }
}

class _SetChipLabel extends StatelessWidget {
  const _SetChipLabel({required this.type, required this.number});

  final SetType type;
  final int? number;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = switch (type) {
      SetType.warmup => (Brand.amber.withValues(alpha: 0.18), Brand.amber),
      SetType.drop => (scheme.tertiaryContainer, scheme.onTertiaryContainer),
      SetType.failure => (scheme.errorContainer, scheme.onErrorContainer),
      SetType.normal => (scheme.surfaceContainerHighest, scheme.onSurface),
    };
    final text = switch (type) {
      SetType.normal => number?.toString() ?? '1',
      _ => type.short,
    };
    return Container(
      width: 36,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(color: fg, fontWeight: FontWeight.w800),
      ),
    );
  }
}
