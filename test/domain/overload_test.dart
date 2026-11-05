import 'package:flutter_test/flutter_test.dart';
import 'package:overload/data/repositories/routine_repository.dart';
import 'package:overload/domain/enums.dart';
import 'package:overload/domain/exercise.dart';
import 'package:overload/domain/models.dart';
import 'package:overload/domain/overload.dart';

import '../helpers.dart';

const _n = SetType.normal;
const _a = SetType.warmup;
const _d = SetType.drop;
const _f = SetType.failure;

SetEntry _s(double kg, int reps, [SetType t = _n]) =>
    SetEntry(type: t, weightKg: kg, reps: reps);

Exercise _withEquipment(Equipment equipment, {ExerciseKind? kind}) {
  final e = exercise(1, kind: kind ?? ExerciseKind.weighted);
  return Exercise(
    id: e.id,
    name: e.name,
    primaryMuscle: e.primaryMuscle,
    secondaryMuscles: e.secondaryMuscles,
    equipment: equipment,
    kind: e.kind,
    rankFactor: e.rankFactor,
    instructions: '',
    isCustom: false,
    seedKey: null,
    restSeconds: null,
    archived: false,
  );
}

List<PlannedSet> _plan(List<SetType> types, int reps, int step) {
  final targets = plannedTargets(types, reps, step);
  return [for (final (i, t) in types.indexed) PlannedSet(t, targets[i])];
}

List<(double?, int?)?> _aims(Progression p) => [
  for (final a in p.sets) a == null ? null : (a.weightKg, a.reps),
];

void main() {
  final barbell = exercise(1); // Equipment.barbell
  const kg = WeightUnit.kg;

  group('plannedTargets', () {
    test('equal reps by default', () {
      expect(plannedTargets([_n, _n, _n], 10, 0), [10, 10, 10]);
    });

    test('descending reps drop on main sets only', () {
      expect(plannedTargets([_a, _n, _n, _n, _d], 10, 1), [
        null,
        10,
        9,
        8,
        null,
      ]);
      expect(plannedTargets([_n, _n, _f], 8, 2), [8, 6, 4]);
    });

    test('never below one rep', () {
      expect(plannedTargets([_n, _n, _n], 2, 3), [2, 1, 1]);
    });

    test('describeTargets shows the descent', () {
      final item = RoutineItem(exerciseId: 1, sets: 3, reps: 10, repStep: 1);
      expect(describeTargets(item), '10 · 9 · 8 reps');
      expect(describeTargets(item.copyWith(repStep: 0)), '10 reps');
    });
  });

  group('suggestProgression', () {
    test('first time: the routine targets, set by set', () {
      final p = suggestProgression(
        plan: _plan([_n, _n, _n], 10, 1),
        previousMain: const [],
        exercise: barbell,
        unit: kg,
        plannedWeightKg: 40,
      );
      expect(p.advice, OverloadAdvice.start);
      expect(_aims(p), [(40.0, 10), (40.0, 9), (40.0, 8)]);
    });

    test('descending reps: each set aims at its own target, not the first', () {
      // Last time 60 kg × 10 · 9 · 7: the third set missed its target of 8.
      final p = suggestProgression(
        plan: _plan([_n, _n, _n], 10, 1),
        previousMain: [_s(60, 10), _s(60, 9), _s(60, 7)],
        exercise: barbell,
        unit: kg,
      );
      expect(p.advice, OverloadAdvice.reachTargets);
      expect(_aims(p), [(60.0, 10), (60.0, 9), (60.0, 8)]);
    });

    test('descending reps all hit: more load, same descent', () {
      final p = suggestProgression(
        plan: _plan([_n, _n, _n], 10, 1),
        previousMain: [_s(60, 10), _s(60, 9), _s(60, 8)],
        exercise: barbell,
        unit: kg,
      );
      expect(p.advice, OverloadAdvice.addLoad);
      expect((p.fromKg, p.toKg), (60.0, 62.5));
      expect(_aims(p), [(62.5, 10), (62.5, 9), (62.5, 8)]);
    });

    test('a miss aims one rep higher, capped at the target', () {
      final p = suggestProgression(
        plan: _plan([_n, _n, _n], 10, 0),
        previousMain: [_s(50, 10), _s(50, 8), _s(50, 6)],
        exercise: barbell,
        unit: kg,
      );
      expect(_aims(p), [(50.0, 10), (50.0, 9), (50.0, 7)]);
    });

    test('warm-ups and drops get no suggestion', () {
      final p = suggestProgression(
        plan: _plan([_a, _n, _d], 8, 0),
        previousMain: [_s(80, 8)],
        exercise: barbell,
        unit: kg,
      );
      expect(_aims(p), [null, (82.5, 8), null]);
    });

    test('without targets (free workout): one more rep than last time', () {
      final p = suggestProgression(
        plan: const [PlannedSet(_n), PlannedSet(_n)],
        previousMain: [_s(30, 12), _s(30, 11)],
        exercise: barbell,
        unit: kg,
      );
      expect(p.advice, OverloadAdvice.addReps);
      expect(_aims(p), [(30.0, 13), (30.0, 12)]);
    });

    test('extra sets today follow the last set of last time', () {
      final p = suggestProgression(
        plan: const [PlannedSet(_n), PlannedSet(_n), PlannedSet(_n)],
        previousMain: [_s(30, 12)],
        exercise: barbell,
        unit: kg,
      );
      expect(_aims(p), [(30.0, 13), (30.0, 13), (30.0, 13)]);
    });

    test('dumbbells go up 2 kg, kettlebells 4 kg, pounds 5 lb', () {
      final hit = [_s(20, 10)];
      final plan = _plan([_n], 10, 0);
      double? to(Exercise e, WeightUnit u) => suggestProgression(
        plan: plan,
        previousMain: hit,
        exercise: e,
        unit: u,
      ).toKg;
      expect(to(_withEquipment(Equipment.dumbbell), kg), 22);
      expect(to(_withEquipment(Equipment.kettlebell), kg), 24);
      expect(to(barbell, WeightUnit.lb), closeTo(20 + 2.268, 0.001));
    });

    test('assisted exercises progress with less assistance', () {
      final p = suggestProgression(
        plan: _plan([_n], 8, 0),
        previousMain: [_s(20, 8)],
        exercise: _withEquipment(
          Equipment.machine,
          kind: ExerciseKind.assisted,
        ),
        unit: kg,
      );
      expect(p.advice, OverloadAdvice.addLoad);
      expect(_aims(p), [(17.5, 8)]);
    });

    test('pure body weight progresses in reps', () {
      final p = suggestProgression(
        plan: _plan([_n, _n], 10, 0),
        previousMain: [_s(0, 10), _s(0, 10)],
        exercise: exercise(1, kind: ExerciseKind.bodyweight),
        unit: kg,
      );
      expect(p.advice, OverloadAdvice.addReps);
      expect(_aims(p), [(0.0, 11), (0.0, 11)]);
    });

    test('duration progresses in seconds', () {
      final p = suggestProgression(
        plan: _plan([_n], 60, 0),
        previousMain: [_s(0, 60)],
        exercise: exercise(1, kind: ExerciseKind.duration),
        unit: kg,
      );
      expect(p.advice, OverloadAdvice.addTime);
      expect(_aims(p), [(0.0, 65)]);
    });
  });
}
