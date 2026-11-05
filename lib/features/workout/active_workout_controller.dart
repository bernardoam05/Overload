import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/repositories/routine_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/enums.dart';
import '../../domain/models.dart';
import '../../domain/overload.dart';
import '../../domain/progression.dart';
import '../../domain/ranks.dart';
import '../../domain/records.dart';
import '../../domain/superset.dart';
import '../notifications/notification_sync.dart';
import 'active_workout.dart';
import 'routine_sync.dart';

/// Draft restored from storage at startup (overridden in `main`).
final initialActiveWorkoutProvider = Provider<ActiveWorkout?>((ref) => null);

final activeWorkoutProvider =
    NotifierProvider<ActiveWorkoutController, ActiveWorkout?>(
      ActiveWorkoutController.new,
    );

class RankChange {
  const RankChange(this.group, this.before, this.after);
  final RankGroup group;
  final RankStanding before;
  final RankStanding after;
}

class WorkoutSummary {
  const WorkoutSummary({
    required this.workoutId,
    required this.record,
    required this.records,
    required this.xp,
    required this.levelBefore,
    required this.levelAfter,
    required this.rankChanges,
    required this.volumeKg,
    required this.edited,
    this.achievementsBefore = const {},
  });

  final int workoutId;
  final WorkoutRecord record;
  final List<PersonalRecord> records;
  final int xp;
  final LevelInfo levelBefore;
  final LevelInfo levelAfter;
  final List<RankChange> rankChanges;
  final double volumeKg;
  final bool edited;

  /// Achievement ids unlocked before this workout, to highlight new ones.
  final Set<String> achievementsBefore;
}

/// A set with its values typed in, ready to be ticked.
bool isFilled(ActiveSet s, {required bool weightOptional}) =>
    (s.reps ?? 0) > 0 && (weightOptional || s.weightKg != null);

/// Rest to start after completing [setId], or `null` for none:
/// - no rest before a drop set, which follows immediately;
/// - no rest in the middle of a superset: the next exercise follows;
/// - a shorter rest after a warm-up;
/// - no rest after the last pending set of the workout.
int? restAfter(ActiveWorkout w, String exId, String setId, int baseSeconds) {
  if (baseSeconds <= 0) return null;
  final position = w.exercises.indexWhere((e) => e.id == exId);
  if (position < 0) return null;
  final exercise = w.exercises[position];
  final i = exercise.sets.indexWhere((s) => s.id == setId);
  if (i < 0) return null;
  final next = i + 1 < exercise.sets.length ? exercise.sets[i + 1] : null;
  if (next != null && !next.done && next.type == SetType.drop) return null;
  final pending = w.exercises.any((e) => e.sets.any((s) => !s.done));
  if (!pending) return null;
  if (exercise.sets[i].type != SetType.warmup &&
      continuesSuperset(
        [for (final e in w.exercises) e.supersetNext],
        [for (final e in w.exercises) e.sets.any((s) => !s.done)],
        position,
      )) {
    return null;
  }
  if (exercise.sets[i].type == SetType.warmup) {
    return baseSeconds < 30 ? baseSeconds : (baseSeconds ~/ 2).clamp(30, 60);
  }
  return baseSeconds;
}

class FinishException implements Exception {
  FinishException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ActiveWorkoutController extends Notifier<ActiveWorkout?> {
  Timer? _restTimer;
  Timer? _saveTimer;
  ActiveWorkout? _unsaved;

  @override
  ActiveWorkout? build() {
    // Saves the pending draft as soon as the app leaves the foreground.
    final lifecycle = AppLifecycleListener(
      onInactive: flushDraft,
      onPause: flushDraft,
    );
    ref.onDispose(() {
      _restTimer?.cancel();
      lifecycle.dispose();
      flushDraft();
    });
    var initial = ref.read(initialActiveWorkoutProvider);
    // A rest longer than requested means the clock moved (or the draft is
    // stale); drop it rather than show hours of rest.
    final end = initial?.restEndsAt;
    if (initial != null &&
        end != null &&
        end.difference(DateTime.now()) >
            Duration(seconds: initial.restTotalSeconds + 5)) {
      initial = initial.copyWith(restEndsAt: () => null);
    }
    _scheduleRestAlarm(initial);
    return initial;
  }

  /// Captured on first use so the draft can still be saved while disposing.
  SettingsRepository? _settingsRepo;
  SettingsRepository get _settings {
    final SettingsRepository repo =
        _settingsRepo ?? ref.read(settingsRepositoryProvider);
    _settingsRepo = repo;
    return repo;
  }

  /// Clears the rest timer when it runs out. On Android the alert itself
  /// (sound, vibration, notification) comes from a native exact alarm, so it
  /// also works with the app in the background; elsewhere it buzzes here.
  void _scheduleRestAlarm(ActiveWorkout? w) {
    _restTimer?.cancel();
    final end = w?.restEndsAt;
    if (end == null) return;
    final remaining = end.difference(DateTime.now());
    if (remaining.isNegative) return;
    _restTimer = Timer(remaining, () {
      if (!ref.read(notificationBridgeProvider).enabled &&
          ref.read(currentProfileProvider).restAlerts) {
        HapticFeedback.heavyImpact();
        SystemSound.play(SystemSoundType.alert);
      }
      final current = state;
      if (current != null && current.restEndsAt == end) {
        _set(current.copyWith(restEndsAt: () => null));
      }
    });
  }

  void _set(ActiveWorkout? next) {
    final restChanged = next?.restEndsAt != state?.restEndsAt;
    state = next;
    if (restChanged) _scheduleRestAlarm(next);
    _saveTimer?.cancel();
    if (next == null) {
      _unsaved = null;
      unawaited(_settings.remove(SettingsRepository.activeWorkoutKey));
    } else {
      // Typing a weight changes the state on every keystroke; writing each one
      // to the database made input sluggish, so saves are coalesced.
      _unsaved = next;
      _settings; // resolve now: disposal can't read providers
      _saveTimer = Timer(const Duration(milliseconds: 400), flushDraft);
    }
  }

  /// Writes the pending draft now, if any.
  void flushDraft() {
    _saveTimer?.cancel();
    final draft = _unsaved;
    if (draft == null) return;
    _unsaved = null;
    unawaited(
      _settings.write(
        SettingsRepository.activeWorkoutKey,
        jsonEncode(draft.toJson()),
      ),
    );
  }

  void _update(ActiveWorkout Function(ActiveWorkout w) change) {
    final current = state;
    if (current != null) _set(change(current));
  }

  void _updateExercise(
    String id,
    ActiveExercise Function(ActiveExercise e) f,
  ) => _update(
    (w) => w.copyWith(
      exercises: [for (final e in w.exercises) e.id == id ? f(e) : e],
    ),
  );

  void _updateSet(
    String exId,
    String setId,
    ActiveSet Function(ActiveSet s) f,
  ) => _updateExercise(
    exId,
    (e) => e.copyWith(sets: [for (final s in e.sets) s.id == setId ? f(s) : s]),
  );

  // ---- Lifecycle ------------------------------------------------------------

  static String defaultName(DateTime t) {
    final h = t.hour;
    if (h < 5) return 'Treino da noite';
    if (h < 12) return 'Treino da manhã';
    if (h < 19) return 'Treino da tarde';
    return 'Treino da noite';
  }

  void startEmpty() {
    final now = DateTime.now();
    _set(
      ActiveWorkout(
        name: defaultName(now),
        startedAt: now,
        exercises: const [],
      ),
    );
  }

  void startFromRoutine(RoutineWithItems routine) {
    _set(
      ActiveWorkout(
        name: routine.routine.name,
        startedAt: DateTime.now(),
        routineId: routine.routine.id,
        exercises: [
          for (final (i, item) in routine.items.indexed)
            ActiveExercise(
              id: newLocalId(),
              exerciseId: item.exerciseId,
              routineIndex: i,
              routineNotes: item.notes,
              repStep: item.repStep,
              plannedWeightKg: item.weightKg,
              supersetNext: item.supersetNext,
              sets: _plannedSets(item.setTypes, item),
            ),
        ],
      ),
    );
  }

  /// Sets start empty: the fields show what to aim for (the routine's target
  /// for each set, adjusted by the last session) and ticking a set fills it.
  static List<ActiveSet> _plannedSets(List<SetType> types, RoutineItem item) {
    final targets = plannedTargets(types, item.reps, item.repStep);
    return [
      for (final (i, type) in types.indexed)
        ActiveSet(id: newLocalId(), type: type, targetReps: targets[i]),
    ];
  }

  /// Starts a new workout with the same exercises and sets as [record]. A
  /// routine workout stays linked to its routine and pinned notes.
  void repeat(WorkoutRecord record) {
    final routine = record.routineId == null
        ? null
        : ref
              .read(routinesProvider)
              .value
              ?.firstWhereOrNull((r) => r.routine.id == record.routineId);
    var exercises = [
      for (final e in record.exercises)
        ActiveExercise(
          id: newLocalId(),
          exerciseId: e.exerciseId,
          supersetNext: e.supersetNext,
          sets: [
            for (final s in e.sets) ActiveSet(id: newLocalId(), type: s.type),
          ],
        ),
    ];
    if (routine != null) {
      final match = matchToRoutine(exercises, routine.items);
      exercises = [
        for (final (i, e) in exercises.indexed)
          match[i] == null
              ? e
              : _linkToItem(e, match[i]!, routine.items[match[i]!]),
      ];
    }
    _set(
      ActiveWorkout(
        name: record.name,
        startedAt: DateTime.now(),
        routineId: record.routineId,
        exercises: exercises,
      ),
    );
  }

  static ActiveExercise _linkToItem(
    ActiveExercise e,
    int index,
    RoutineItem item,
  ) {
    final targets = plannedTargets(
      [for (final s in e.sets) s.type],
      item.reps,
      item.repStep,
    );
    return ActiveExercise(
      id: e.id,
      exerciseId: e.exerciseId,
      sets: [
        for (final (j, s) in e.sets.indexed)
          s.copyWith(targetReps: () => targets[j]),
      ],
      routineIndex: index,
      routineNotes: item.notes,
      repStep: item.repStep,
      plannedWeightKg: item.weightKg,
      supersetNext: e.supersetNext,
    );
  }

  /// Loads a finished workout for editing; finishing replaces it.
  void edit(WorkoutRecord record) {
    _set(
      ActiveWorkout(
        name: record.name,
        startedAt: record.startedAt,
        notes: record.notes,
        routineId: record.routineId,
        editingWorkoutId: record.id,
        editingEndedAt: record.endedAt,
        exercises: [
          for (final e in record.exercises)
            ActiveExercise(
              id: newLocalId(),
              exerciseId: e.exerciseId,
              notes: e.notes,
              supersetNext: e.supersetNext,
              form: e.form,
              sets: [
                for (final s in e.sets)
                  ActiveSet(
                    id: newLocalId(),
                    type: s.type,
                    weightKg: s.weightKg,
                    reps: s.reps,
                    done: true,
                  ),
              ],
            ),
        ],
      ),
    );
  }

  void discard() => _set(null);

  // ---- Editing --------------------------------------------------------------

  void rename(String name) {
    final trimmed = name.trim();
    if (trimmed.isNotEmpty) _update((w) => w.copyWith(name: trimmed));
  }

  void setNotes(String notes) => _update((w) => w.copyWith(notes: notes));

  void addExercises(List<int> exerciseIds) => _update(
    (w) => w.copyWith(
      exercises: [
        ...w.exercises,
        for (final id in exerciseIds)
          ActiveExercise(
            id: newLocalId(),
            exerciseId: id,
            sets: [ActiveSet(id: newLocalId())],
          ),
      ],
    ),
  );

  /// Removes an exercise and returns it with its position, for undo.
  (int, ActiveExercise)? removeExercise(String id) {
    final w = state;
    if (w == null) return null;
    final index = w.exercises.indexWhere((e) => e.id == id);
    if (index < 0) return null;
    final removed = w.exercises[index];
    _set(w.copyWith(exercises: [...w.exercises]..removeAt(index)));
    return (index, removed);
  }

  void restoreExercise(int index, ActiveExercise exercise) => _update(
    (w) => w.copyWith(
      exercises: [...w.exercises]
        ..insert(index.clamp(0, w.exercises.length), exercise),
    ),
  );

  void replaceExercise(String id, int exerciseId) => _updateExercise(
    id,
    (e) => e.copyWith(
      exerciseId: exerciseId,
      sets: [for (final s in e.sets) s.copyWith(done: false)],
    ),
  );

  void moveExercise(int oldIndex, int newIndex) => _update((w) {
    final list = [...w.exercises];
    final item = list.removeAt(oldIndex);
    list.insert(newIndex.clamp(0, list.length), item);
    return w.copyWith(exercises: list);
  });

  void setExerciseNotes(String id, String notes) =>
      _updateExercise(id, (e) => e.copyWith(notes: notes));

  /// Edits the note pinned in the routine (applied to the routine only if
  /// accepted when finishing).
  void setRoutineNotes(String id, String notes) =>
      _updateExercise(id, (e) => e.copyWith(routineNotes: notes));

  /// Adds a warm-up before the working sets (after any existing warm-ups).
  void addWarmup(String exId) => _updateExercise(exId, (e) {
    final at = e.sets.lastIndexWhere((s) => s.type == SetType.warmup) + 1;
    return e.copyWith(
      sets: [...e.sets]
        ..insert(at, ActiveSet(id: newLocalId(), type: SetType.warmup)),
    );
  });

  /// Replaces the pending warm-ups of an exercise with [steps], filled in,
  /// before its working sets. Warm-ups already done stay.
  void setWarmups(String exId, List<({double kg, int reps})> steps) =>
      _updateExercise(exId, (e) {
        final done = [
          for (final s in e.sets)
            if (s.type == SetType.warmup && s.done) s,
        ];
        final rest = [
          for (final s in e.sets)
            if (s.type != SetType.warmup) s,
        ];
        return e.copyWith(
          sets: [
            ...done,
            for (final w in steps)
              ActiveSet(
                id: newLocalId(),
                type: SetType.warmup,
                weightKg: w.kg,
                reps: w.reps,
              ),
            ...rest,
          ],
        );
      });

  /// Adds a drop set at the end, empty so last time's drop shows as a hint.
  void addDrop(String exId) => _updateExercise(
    exId,
    (e) => e.copyWith(
      sets: [
        ...e.sets,
        ActiveSet(id: newLocalId(), type: SetType.drop),
      ],
    ),
  );

  /// Adds a working set like the last one (values copied). Drops stay at
  /// the end, so the new set goes before them. With descending reps the new
  /// set continues the descent.
  void addSet(String exId) => _updateExercise(exId, (e) {
    var at = e.sets.length;
    while (at > 0 && e.sets[at - 1].type == SetType.drop) {
      at--;
    }
    final last = e.sets
        .take(at)
        .lastWhereOrNull((s) => s.type != SetType.warmup);
    int? lower(int? reps) =>
        reps == null ? null : (reps - e.repStep).clamp(1, 999);
    return e.copyWith(
      sets: [...e.sets]
        ..insert(
          at,
          ActiveSet(
            id: newLocalId(),
            type: last?.type ?? SetType.normal,
            weightKg: last?.weightKg,
            reps: lower(last?.reps),
            targetReps: lower(last?.targetReps),
          ),
        ),
    );
  });

  /// Rates the form of an exercise; the same rating again clears it.
  void setForm(String exId, FormRating rating) => _updateExercise(
    exId,
    (e) => e.copyWith(form: () => e.form == rating ? null : rating),
  );

  /// Links (or unlinks) an exercise with the next one in a superset.
  void toggleSuperset(String exId) =>
      _updateExercise(exId, (e) => e.copyWith(supersetNext: !e.supersetNext));

  /// Removes a set and returns it with its position, for undo.
  (int, ActiveSet)? removeSet(String exId, String setId) {
    final exercise = state?.exercises.where((e) => e.id == exId).firstOrNull;
    final index = exercise?.sets.indexWhere((s) => s.id == setId) ?? -1;
    if (exercise == null || index < 0) return null;
    final removed = exercise.sets[index];
    _updateExercise(
      exId,
      (e) => e.copyWith(sets: [...e.sets]..removeAt(index)),
    );
    return (index, removed);
  }

  void restoreSet(String exId, int index, ActiveSet set) => _updateExercise(
    exId,
    (e) => e.copyWith(
      sets: [...e.sets]..insert(index.clamp(0, e.sets.length), set),
    ),
  );

  void setWeight(String exId, String setId, double? kg) =>
      _updateSet(exId, setId, (s) => s.copyWith(weightKg: () => kg));

  void setReps(String exId, String setId, int? reps) =>
      _updateSet(exId, setId, (s) => s.copyWith(reps: () => reps));

  void setType(String exId, String setId, SetType type) =>
      _updateSet(exId, setId, (s) => s.copyWith(type: type));

  /// Toggles completion. Empty fields are filled with the [hint] values
  /// (today's aim, or the previous performance) so a set can be ticked with
  /// one tap. Returns whether the set is now done.
  bool toggleDone(
    String exId,
    String setId, {
    SetAim? hint,
    required bool weightRequired,
    int? restSeconds,
  }) {
    final w = state;
    if (w == null) return false;
    final set = w.exercises
        .firstWhere((e) => e.id == exId)
        .sets
        .firstWhere((s) => s.id == setId);
    if (set.done) {
      _updateSet(exId, setId, (s) => s.copyWith(done: false));
      return false;
    }
    final reps = set.reps ?? hint?.reps;
    final weight =
        set.weightKg ?? hint?.weightKg ?? (weightRequired ? null : 0);
    if (reps == null || reps <= 0 || weight == null || weight < 0) return false;
    _updateSet(
      exId,
      setId,
      (s) => s.copyWith(done: true, reps: () => reps, weightKg: () => weight),
    );
    final after = state;
    if (restSeconds != null && after != null && !after.isEditing) {
      final rest = restAfter(after, exId, setId, restSeconds);
      if (rest != null) startRest(rest);
    }
    return true;
  }

  /// Marks every set that already has its values typed in as done (used
  /// when finishing with sets the user forgot to tick). Returns how many.
  int completeFilledSets(Set<int> weightOptionalExerciseIds) {
    final w = state;
    if (w == null) return 0;
    var count = 0;
    _set(
      w.copyWith(
        exercises: [
          for (final e in w.exercises)
            e.copyWith(
              sets: [
                for (final s in e.sets)
                  if (!s.done &&
                      isFilled(
                        s,
                        weightOptional: weightOptionalExerciseIds.contains(
                          e.exerciseId,
                        ),
                      )) ...[
                    s.copyWith(done: true, weightKg: () => s.weightKg ?? 0),
                  ] else
                    s,
              ],
            ),
        ],
      ),
    );
    for (final e in w.exercises) {
      for (final s in e.sets) {
        if (!s.done &&
            isFilled(
              s,
              weightOptional: weightOptionalExerciseIds.contains(e.exerciseId),
            )) {
          count++;
        }
      }
    }
    return count;
  }

  // ---- Rest timer -------------------------------------------------------------

  void startRest(int seconds) => _update(
    (w) => w.copyWith(
      restEndsAt: () => DateTime.now().add(Duration(seconds: seconds)),
      restTotalSeconds: seconds,
    ),
  );

  void adjustRest(int deltaSeconds) => _update((w) {
    final end = w.restEndsAt;
    if (end == null) return w;
    final next = end.add(Duration(seconds: deltaSeconds));
    if (!next.isAfter(DateTime.now())) {
      return w.copyWith(restEndsAt: () => null);
    }
    return w.copyWith(
      restEndsAt: () => next,
      restTotalSeconds: (w.restTotalSeconds + deltaSeconds).clamp(1, 3600),
    );
  });

  void skipRest() => _update((w) => w.copyWith(restEndsAt: () => null));

  /// Ends the rest if its time is up (the native alarm fired).
  void clearRestIfDue() => _update((w) {
    final end = w.restEndsAt;
    if (end == null ||
        end.isAfter(DateTime.now().add(const Duration(seconds: 2)))) {
      return w;
    }
    return w.copyWith(restEndsAt: () => null);
  });

  // ---- Finish -------------------------------------------------------------------

  Future<WorkoutSummary> finish() async {
    final w = state;
    if (w == null) throw FinishException('Não há nenhum treino a decorrer.');
    final library = ref.read(libraryProvider);
    final entries = <ExerciseEntry>[];
    for (final e in w.exercises) {
      final kind = library[e.exerciseId]?.kind ?? ExerciseKind.weighted;
      final sets = [
        for (final s in e.sets)
          if (s.done && (s.reps ?? 0) > 0)
            SetEntry(
              type: s.type,
              weightKg: kind == ExerciseKind.duration ? 0 : (s.weightKg ?? 0),
              reps: s.reps!,
            ),
      ];
      if (sets.isNotEmpty) {
        entries.add(
          ExerciseEntry(
            exerciseId: e.exerciseId,
            sets: sets,
            notes: e.notes,
            supersetNext: e.supersetNext,
            form: e.form,
          ),
        );
      }
    }
    if (entries.isEmpty) {
      throw FinishException('Completa pelo menos uma série antes de terminar.');
    }

    final achievementsBefore = {
      for (final a in ref.read(achievementsProvider))
        if (a.unlocked) a.achievement.id,
    };
    final allHistory = ref.read(historyListProvider);
    final history = [
      for (final h in allHistory)
        if (h.id != w.editingWorkoutId) h,
    ];
    final bodyWeight = ref.read(bodyWeightProvider);
    final hasBodyWeight = ref.read(hasBodyWeightProvider);
    final sex = ref.read(currentProfileProvider).sex;
    final now = DateTime.now();
    // Never before the start, even if the device clock moved backwards.
    final endedAt =
        w.editingEndedAt ?? (now.isBefore(w.startedAt) ? w.startedAt : now);

    var record = WorkoutRecord(
      id: w.editingWorkoutId ?? -1,
      name: w.name,
      startedAt: w.startedAt,
      endedAt: endedAt,
      notes: w.notes,
      routineId: w.routineId,
      bodyWeightKg: hasBodyWeight ? bodyWeight : null,
      exercises: entries,
    );
    final prs = newRecords(record, history, library, bodyWeightKg: bodyWeight);
    final xp = workoutXp(
      workingSets: record.setCount,
      duration: record.duration,
      personalRecords: prs.length,
    );
    record = WorkoutRecord(
      id: record.id,
      name: record.name,
      startedAt: record.startedAt,
      endedAt: record.endedAt,
      notes: record.notes,
      routineId: record.routineId,
      bodyWeightKg: record.bodyWeightKg,
      exercises: record.exercises,
      xp: xp,
    );

    RankSummary ranksOf(List<WorkoutRecord> h) => computeRanks(
      history: h,
      library: library,
      bodyWeightKg: bodyWeight,
      sex: sex,
    );
    final before = ranksOf(history);
    final after = ranksOf([...history, record]);
    final previousXp = history.fold(0, (s, h) => s + h.xp);

    final repo = ref.read(workoutRepositoryProvider);
    final int id;
    if (w.editingWorkoutId != null) {
      id = w.editingWorkoutId!;
      await repo.replace(id, record);
    } else {
      id = await repo.insert(record);
      if (w.routineId != null) {
        await ref.read(routineRepositoryProvider).markUsed(w.routineId!);
      }
    }
    _set(null);
    // A finished workout is the moment new data most deserves a copy.
    unawaited(ref.read(autoBackupProvider).runIfDue());

    return WorkoutSummary(
      workoutId: id,
      record: record,
      records: prs,
      xp: xp,
      levelBefore: levelForXp(previousXp),
      levelAfter: levelForXp(previousXp + xp),
      rankChanges: [
        for (final g in RankGroup.values)
          if (after.groups[g]!.score > before.groups[g]!.score + 1e-9)
            RankChange(g, before.groups[g]!, after.groups[g]!),
      ],
      volumeKg: record.volume(library),
      edited: w.isEditing,
      achievementsBefore: achievementsBefore,
    );
  }
}
