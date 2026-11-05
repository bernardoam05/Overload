import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/repositories/routine_repository.dart';
import '../../domain/models.dart';
import '../../widgets/common.dart';
import '../workout/finish_sheet.dart';
import '../workout/routine_sync.dart';

/// Takes changes from a finished workout to a routine, as the finish sheet
/// does at the end of a workout. The workout's own routine is proposed;
/// any other can be picked.
Future<void> takeWorkoutToRoutine(
  BuildContext context,
  WidgetRef ref,
  WorkoutRecord workout,
) async {
  final routines = ref.read(routinesProvider).value ?? const [];
  if (routines.isEmpty) {
    showMessage(context, 'Ainda não tens rotinas. Usa "Guardar como rotina".');
    return;
  }
  var routine = routines.firstWhereOrNull(
    (r) => r.routine.id == workout.routineId,
  );
  routine ??= await showModalBottomSheet<RoutineWithItems>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text('Comparar com que rotina?'),
          ),
          for (final r in routines)
            ListTile(
              title: Text(r.routine.name),
              subtitle: Text('${r.items.length} exercícios'),
              onTap: () => Navigator.pop(context, r),
            ),
        ],
      ),
    ),
  );
  if (routine == null || !context.mounted) return;

  final library = ref.read(libraryProvider);
  final sync = routineSync(
    workoutAgainstRoutine(workout, routine),
    routine,
    library,
  );
  if (sync == null) {
    showMessage(context, 'A rotina «${routine.routine.name}» já está igual.');
    return;
  }
  final selected = await showModalBottomSheet<Set<String>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _UpdateSheet(sync: sync),
  );
  if (selected == null || selected.isEmpty) return;
  await ref
      .read(routineRepositoryProvider)
      .save(
        id: sync.routine.routine.id,
        name: sync.routine.routine.name,
        notes: sync.routine.routine.notes,
        items: sync.apply(selected),
      );
  if (context.mounted) {
    showMessage(context, 'Rotina «${sync.routine.routine.name}» atualizada.');
  }
}

class _UpdateSheet extends StatefulWidget {
  const _UpdateSheet({required this.sync});
  final RoutineSync sync;

  @override
  State<_UpdateSheet> createState() => _UpdateSheetState();
}

class _UpdateSheetState extends State<_UpdateSheet> {
  // From a past workout everything is a deliberate choice: start with the
  // usual proposals and let the user tick the rest.
  late final Set<String> _selected = {...widget.sync.defaultSelection};

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RoutineChangesList(
            sync: widget.sync,
            selected: _selected,
            onChanged: (id, on) =>
                setState(() => on ? _selected.add(id) : _selected.remove(id)),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _selected.isEmpty
                ? null
                : () => Navigator.pop(context, _selected),
            child: Text(
              _selected.length == 1
                  ? 'Aplicar 1 alteração'
                  : 'Aplicar ${_selected.length} alterações',
            ),
          ),
        ],
      ),
    ),
  );
}
