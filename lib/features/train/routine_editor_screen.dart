import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../data/repositories/routine_repository.dart';
import '../../domain/enums.dart';
import '../../app/theme.dart';
import '../../widgets/common.dart';

/// Pre-filled content for a new routine (duplicate / save workout as routine).
class RoutineTemplate {
  const RoutineTemplate(this.name, this.items);
  final String name;
  final List<RoutineItem> items;
}

class _Row {
  _Row(this.key, this.item);
  final int key;
  RoutineItem item;
}

class RoutineEditorScreen extends ConsumerStatefulWidget {
  const RoutineEditorScreen({super.key, this.routineId, this.template});

  final int? routineId;
  final RoutineTemplate? template;

  @override
  ConsumerState<RoutineEditorScreen> createState() =>
      _RoutineEditorScreenState();
}

class _RoutineEditorScreenState extends ConsumerState<RoutineEditorScreen> {
  final _name = TextEditingController();
  final List<_Row> _rows = [];
  int _nextKey = 0;
  bool _loaded = false;
  bool _dirty = false;
  String _routineNotes = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    final existing = widget.routineId == null
        ? null
        : ref
              .read(routinesProvider)
              .value
              ?.firstWhereOrNull((r) => r.routine.id == widget.routineId);
    final name = existing?.routine.name ?? widget.template?.name ?? '';
    final items = existing?.items ?? widget.template?.items ?? const [];
    _name.text = name;
    _routineNotes = existing?.routine.notes ?? '';
    _rows.addAll([for (final i in items) _Row(_nextKey++, i)]);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final ids = await context.push<List<int>>('/exercises/pick');
    if (ids == null) return;
    setState(() {
      _dirty = true;
      _rows.addAll([
        for (final id in ids) _Row(_nextKey++, RoutineItem(exerciseId: id)),
      ]);
    });
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      showMessage(context, 'Dá um nome à rotina.');
      return;
    }
    await ref
        .read(routineRepositoryProvider)
        .save(
          id: widget.routineId,
          name: _name.text,
          notes: _routineNotes,
          items: [for (final r in _rows) r.item],
        );
    if (mounted) context.pop();
  }

  Future<bool> _confirmLeave() async {
    if (!_dirty) return true;
    return confirm(
      context,
      title: 'Descartar alterações?',
      confirmLabel: 'Descartar',
      destructive: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(libraryProvider);
    final theme = Theme.of(context);

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmLeave() && context.mounted) {
          _dirty = false;
          context.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.routineId == null ? 'Nova rotina' : 'Editar rotina',
          ),
          actions: [
            TextButton(onPressed: _save, child: const Text('Guardar')),
            const SizedBox(width: 8),
          ],
        ),
        body: ReorderableListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          header: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: TextField(
              controller: _name,
              maxLength: 80,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => _dirty = true,
              style: theme.textTheme.titleLarge,
              decoration: const InputDecoration(
                hintText: 'Nome da rotina',
                counterText: '',
              ),
            ),
          ),
          footer: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: FilledButton.tonalIcon(
              onPressed: _add,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Adicionar exercícios'),
            ),
          ),
          itemCount: _rows.length,
          onReorder: (oldIndex, newIndex) => setState(() {
            _dirty = true;
            if (newIndex > oldIndex) newIndex--;
            _rows.insert(newIndex, _rows.removeAt(oldIndex));
          }),
          itemBuilder: (context, i) {
            final row = _rows[i];
            final ex = library[row.item.exerciseId];
            final isTime = ex?.kind == ExerciseKind.duration;
            return Padding(
              key: ValueKey(row.key),
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 4, 12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          ReorderableDragStartListener(
                            index: i,
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(Icons.drag_indicator_rounded),
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (ex != null)
                            MuscleAvatar(ex.primaryMuscle, size: 34),
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
                            onPressed: () => setState(() {
                              _dirty = true;
                              _rows.removeAt(i);
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: SetPlanEditor(
                          types: row.item.setTypes,
                          onChanged: (types) => setState(() {
                            _dirty = true;
                            row.item = row.item.copyWith(setTypes: types);
                          }),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _Stepper(
                              label: isTime
                                  ? 'Segundos por série'
                                  : 'Reps alvo por série',
                              value: row.item.reps,
                              min: 1,
                              max: isTime ? 900 : 100,
                              step: isTime ? 15 : 1,
                              onChanged: (v) => setState(() {
                                _dirty = true;
                                row.item = row.item.copyWith(reps: v);
                              }),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(0, 8, 8, 0),
                        child: TextFormField(
                          key: ValueKey('note-${row.key}'),
                          initialValue: row.item.notes,
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
                          onChanged: (v) {
                            _dirty = true;
                            row.item = row.item.copyWith(notes: v);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
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
