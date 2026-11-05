import 'package:collection/collection.dart';

import '../../data/repositories/routine_repository.dart';
import '../../domain/enums.dart';
import '../../domain/exercise.dart';
import '../../domain/models.dart';
import 'active_workout.dart';

/// What belongs to the workout and what belongs to the routine:
///
/// - Everything typed or changed during a workout (weights, reps, ticks,
///   added or removed sets, warm-ups, drops, exercises, notes) is part of
///   that workout and is saved in its history.
/// - The routine is the plan for the next time: the exercises and their
///   order, the type of each planned set, the target reps and the pinned
///   note. It only changes in the routine editor, or when, at the end of a
///   workout, the user accepts the changes listed by [routineSync].

enum RoutineChangeKind {
  sets,
  notes,
  replaced,
  added,
  removed,
  order,
  supersets,
  targets,
}

class RoutineChange {
  const RoutineChange({
    required this.id,
    required this.kind,
    required this.title,
    this.detail,
    required this.selectedByDefault,
  });

  /// Stable key used to select the change.
  final String id;
  final RoutineChangeKind kind;
  final String title;
  final String? detail;

  /// Additions (a warm-up, a drop, a note, an exercise) are proposed;
  /// removals and reorders, often one-offs (a busy machine, a tired day),
  /// are listed but not ticked.
  final bool selectedByDefault;
}

/// Pairs each workout exercise with the routine item it came from.
///
/// Uses the stored [ActiveExercise.routineIndex]; workouts without it
/// (drafts from older versions, or a repeated workout) are matched by
/// exercise, in order.
List<int?> matchToRoutine(
  List<ActiveExercise> exercises,
  List<RoutineItem> items,
) {
  final result = List<int?>.filled(exercises.length, null);
  final used = <int>{};
  final hasIndices = exercises.any((e) => e.routineIndex != null);
  for (final (i, e) in exercises.indexed) {
    if (hasIndices) {
      final idx = e.routineIndex;
      if (idx != null && idx >= 0 && idx < items.length && used.add(idx)) {
        result[i] = idx;
      }
    } else {
      for (final (j, item) in items.indexed) {
        if (item.exerciseId == e.exerciseId && used.add(j)) {
          result[i] = j;
          break;
        }
      }
    }
  }
  return result;
}

List<SetType> setTypesOf(ActiveExercise e) => [for (final s in e.sets) s.type];

/// The differences between a finished workout and its routine, and how to
/// apply a selection of them.
class RoutineSync {
  RoutineSync._(this.routine, this._exercises, this._match, this.changes);

  final RoutineWithItems routine;
  final List<ActiveExercise> _exercises;
  final List<int?> _match;
  final List<RoutineChange> changes;

  Set<String> get defaultSelection => {
    for (final c in changes)
      if (c.selectedByDefault) c.id,
  };

  /// The routine's items with the [selected] changes applied.
  List<RoutineItem> apply(Set<String> selected) {
    final items = routine.items;
    final keepOrder = !selected.contains('order');
    final slots = <({double key, RoutineItem item})>[];
    final positionInWorkout = <int, int>{};
    var lastKey = -1.0;

    for (final (i, e) in _exercises.indexed) {
      final idx = _match[i];
      if (idx != null) {
        positionInWorkout[idx] = i;
        var item = items[idx];
        if (selected.contains('replaced:$idx')) {
          item = item.copyWith(exerciseId: e.exerciseId);
        }
        if (selected.contains('sets:$idx') && e.sets.isNotEmpty) {
          item = item.copyWith(setTypes: setTypesOf(e));
        }
        if (selected.contains('targets:$idx')) {
          final t = doneTargets(e);
          if (t != null) item = item.copyWith(reps: t.reps, repStep: t.step);
        }
        if (selected.contains('notes:$idx')) {
          item = item.copyWith(notes: e.routineNotes.trim());
        }
        if (selected.contains('supersets')) {
          item = item.copyWith(supersetNext: e.supersetNext);
        }
        lastKey = keepOrder ? idx.toDouble() : i.toDouble();
        slots.add((key: lastKey, item: item));
      } else if (selected.contains('added:${e.id}') && e.sets.isNotEmpty) {
        lastKey = keepOrder ? lastKey + 1e-3 : i.toDouble();
        slots.add((key: lastKey, item: _newItem(e)));
      }
    }

    for (final (idx, item) in items.indexed) {
      if (positionInWorkout.containsKey(idx)) continue;
      if (selected.contains('removed:$idx')) continue;
      final double key;
      if (keepOrder) {
        key = idx.toDouble();
      } else {
        // Right after the closest earlier routine item still in the workout.
        final before = [
          for (var j = idx - 1; j >= 0; j--) ?positionInWorkout[j],
        ].firstOrNull;
        key = (before ?? -1) + 0.5 + idx * 1e-4;
      }
      slots.add((key: key, item: item));
    }

    mergeSort(slots, compare: (a, b) => a.key.compareTo(b.key));
    return [for (final s in slots) s.item];
  }

  static RoutineItem _newItem(ActiveExercise e) {
    final reps = [
      for (final s in e.sets)
        if (s.type != SetType.warmup && (s.reps ?? 0) > 0) s.reps!,
    ];
    final main = [
      for (final s in e.sets)
        if ((s.type == SetType.normal || s.type == SetType.failure) &&
            (s.reps ?? 0) > 0)
          s.reps!,
    ];
    final step = descendingStep(main);
    final common = reps.isEmpty
        ? 10
        : maxBy(reps.toSet(), (r) => reps.where((x) => x == r).length)!;
    return RoutineItem(
      exerciseId: e.exerciseId,
      setTypes: setTypesOf(e),
      reps: step > 0 ? main.first : common,
      repStep: step,
      notes: e.routineNotes.trim(),
      supersetNext: e.supersetNext,
    );
  }
}

/// Target reps implied by the main sets done in [e]: the first set's reps
/// with an even descent (10 · 9 · 8), else the most common reps; `null` when
/// no main set was done.
({int reps, int step})? doneTargets(ActiveExercise e) {
  final main = [
    for (final s in e.sets)
      if ((s.type == SetType.normal || s.type == SetType.failure) &&
          s.done &&
          (s.reps ?? 0) > 0)
        s.reps!,
  ];
  if (main.isEmpty) return null;
  final step = descendingStep(main);
  if (step > 0) return (reps: main.first, step: step);
  final common = maxBy(main.toSet(), (r) => main.where((x) => x == r).length)!;
  return (reps: common, step: 0);
}

/// The constant drop in reps between consecutive sets (10 · 9 · 8 → 1), or
/// 0 when the reps don't descend evenly.
int descendingStep(List<int> reps) {
  if (reps.length < 2) return 0;
  final step = reps[0] - reps[1];
  if (step <= 0 || step > RoutineItem.maxRepStep) return 0;
  for (var i = 1; i < reps.length; i++) {
    if (reps[i - 1] - reps[i] != step) return 0;
  }
  return step;
}

/// Lists what changed in [workout] compared with [routine]; `null` when the
/// workout is not from a routine, is an edit of a past workout, or nothing
/// that belongs to the routine changed.
RoutineSync? routineSync(
  ActiveWorkout workout,
  RoutineWithItems? routine,
  Map<int, Exercise> library,
) {
  if (routine == null || workout.isEditing) return null;
  if (workout.routineId != routine.routine.id) return null;
  final items = routine.items;
  final exercises = workout.exercises;
  final match = matchToRoutine(exercises, items);
  String name(int id) => library[id]?.name ?? 'Exercício removido';

  final changes = <RoutineChange>[];
  for (final (i, e) in exercises.indexed) {
    final idx = match[i];
    if (idx == null) {
      if (e.sets.isEmpty) continue;
      changes.add(
        RoutineChange(
          id: 'added:${e.id}',
          kind: RoutineChangeKind.added,
          title: 'Adicionar ${name(e.exerciseId)}',
          detail: describeSetTypes(setTypesOf(e)),
          selectedByDefault: true,
        ),
      );
      continue;
    }
    final item = items[idx];
    if (item.exerciseId != e.exerciseId) {
      changes.add(
        RoutineChange(
          id: 'replaced:$idx',
          kind: RoutineChangeKind.replaced,
          title: 'Trocar ${name(item.exerciseId)} por ${name(e.exerciseId)}',
          selectedByDefault: false,
        ),
      );
    }
    final types = setTypesOf(e);
    if (types.isNotEmpty &&
        !const ListEquality<SetType>().equals(types, item.setTypes)) {
      int count(List<SetType> l, SetType t) => l.where((x) => x == t).length;
      final added = SetType.values.any(
        (t) => count(types, t) > count(item.setTypes, t),
      );
      changes.add(
        RoutineChange(
          id: 'sets:$idx',
          kind: RoutineChangeKind.sets,
          title: '${name(e.exerciseId)}: ${describeSetTypes(types)}',
          detail: 'Na rotina: ${describeSetTypes(item.setTypes)}',
          selectedByDefault: added,
        ),
      );
    }
    final done = doneTargets(e);
    if (done != null && (done.reps != item.reps || done.step != item.repStep)) {
      final planned = item.copyWith(
        setTypes: types.isEmpty ? null : types,
        reps: done.reps,
        repStep: done.step,
      );
      changes.add(
        RoutineChange(
          id: 'targets:$idx',
          kind: RoutineChangeKind.targets,
          title: '${name(e.exerciseId)}: alvo ${describeTargets(planned)}',
          detail: 'Na rotina: ${describeTargets(item)}',
          selectedByDefault: false,
        ),
      );
    }
    if (e.routineNotes.trim() != item.notes.trim()) {
      final note = e.routineNotes.trim();
      changes.add(
        RoutineChange(
          id: 'notes:$idx',
          kind: RoutineChangeKind.notes,
          title: '${name(e.exerciseId)}: nota fixa',
          detail: note.isEmpty ? 'Apagar a nota' : note,
          selectedByDefault: true,
        ),
      );
    }
  }

  // Superset links between exercises that are in the routine.
  var linked = false;
  var unlinked = false;
  for (final (i, e) in exercises.indexed) {
    final idx = match[i];
    if (idx == null) continue;
    if (e.supersetNext && !items[idx].supersetNext) linked = true;
    if (!e.supersetNext && items[idx].supersetNext) unlinked = true;
  }
  if (linked || unlinked) {
    changes.add(
      RoutineChange(
        id: 'supersets',
        kind: RoutineChangeKind.supersets,
        title: 'Guardar as superséries deste treino',
        detail: linked && unlinked
            ? 'Juntaste e separaste exercícios'
            : linked
            ? 'Juntaste exercícios em supersérie'
            : 'Separaste exercícios de uma supersérie',
        selectedByDefault: linked,
      ),
    );
  }

  final matched = match.whereType<int>().toList();
  for (final (idx, item) in items.indexed) {
    if (matched.contains(idx)) continue;
    changes.add(
      RoutineChange(
        id: 'removed:$idx',
        kind: RoutineChangeKind.removed,
        title: 'Tirar ${name(item.exerciseId)} da rotina',
        selectedByDefault: false,
      ),
    );
  }

  final reordered = !const ListEquality<int>().equals(
    matched,
    [...matched]..sort(),
  );
  if (reordered) {
    changes.add(
      const RoutineChange(
        id: 'order',
        kind: RoutineChangeKind.order,
        title: 'Guardar a nova ordem dos exercícios',
        selectedByDefault: false,
      ),
    );
  }

  if (changes.isEmpty) return null;
  return RoutineSync._(routine, exercises, match, changes);
}

/// A finished workout seen as if it had just been done from [routine], so
/// [routineSync] can list what to take to the routine afterwards. Pinned
/// notes are not in the history, so they are taken from the routine (and
/// never show as changes).
ActiveWorkout workoutAgainstRoutine(
  WorkoutRecord record,
  RoutineWithItems routine,
) {
  var exercises = [
    for (final (i, e) in record.exercises.indexed)
      ActiveExercise(
        id: 'h$i',
        exerciseId: e.exerciseId,
        notes: e.notes,
        supersetNext: e.supersetNext,
        form: e.form,
        sets: [
          for (final (j, s) in e.sets.indexed)
            ActiveSet(
              id: 'h$i-$j',
              type: s.type,
              weightKg: s.weightKg,
              reps: s.reps,
              done: true,
            ),
        ],
      ),
  ];
  final match = matchToRoutine(exercises, routine.items);
  // Exercises left over on both sides were most likely swapped (stiff for
  // deadlift): pair them in order so they show as replacements.
  final freeItems = [
    for (var j = 0; j < routine.items.length; j++)
      if (!match.contains(j)) j,
  ];
  for (var i = 0; i < match.length && freeItems.isNotEmpty; i++) {
    if (match[i] == null) match[i] = freeItems.removeAt(0);
  }
  exercises = [
    for (final (i, e) in exercises.indexed)
      match[i] == null
          ? e
          : ActiveExercise(
              id: e.id,
              exerciseId: e.exerciseId,
              notes: e.notes,
              supersetNext: e.supersetNext,
              form: e.form,
              sets: e.sets,
              routineIndex: match[i],
              routineNotes: routine.items[match[i]!].notes,
            ),
  ];
  return ActiveWorkout(
    name: record.name,
    startedAt: record.startedAt,
    routineId: routine.routine.id,
    exercises: exercises,
  );
}
