import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../data/repositories/routine_repository.dart';
import '../../widgets/common.dart';
import 'routine_item_card.dart';

export 'routine_item_card.dart' show SetPlanEditor;

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
            return Padding(
              key: ValueKey(row.key),
              padding: const EdgeInsets.only(bottom: 10),
              child: RoutineItemCard(
                index: i,
                rowKey: row.key,
                item: row.item,
                exercise: library[row.item.exerciseId],
                isLast: i == _rows.length - 1,
                linkedFromPrevious: i > 0 && _rows[i - 1].item.supersetNext,
                onChanged: (item) => setState(() {
                  _dirty = true;
                  row.item = item;
                }),
                onNotes: (v) {
                  _dirty = true;
                  row.item = row.item.copyWith(notes: v);
                },
                onRemove: () => setState(() {
                  _dirty = true;
                  _rows.removeAt(i);
                }),
              ),
            );
          },
        ),
      ),
    );
  }
}
