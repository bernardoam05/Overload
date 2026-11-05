import 'package:flutter_test/flutter_test.dart';
import 'package:overload/data/repositories/settings_repository.dart';
import 'package:overload/domain/enums.dart';
import 'package:overload/domain/exercise.dart';

import '../helpers.dart';

Exercise _withCategory(ExerciseCategory c, {int? rest}) {
  final e = exercise(1);
  return Exercise(
    id: e.id,
    name: e.name,
    primaryMuscle: e.primaryMuscle,
    secondaryMuscles: const [],
    equipment: e.equipment,
    kind: e.kind,
    rankFactor: null,
    instructions: '',
    isCustom: false,
    seedKey: null,
    restSeconds: rest,
    archived: false,
    category: c,
  );
}

void main() {
  test('rest: the exercise own, else by kind of lift, else the default', () {
    const p = Profile(defaultRestSeconds: 90);
    expect(p.restFor(_withCategory(ExerciseCategory.heavyCompound)), 150);
    expect(p.restFor(_withCategory(ExerciseCategory.highRep)), 60);
    expect(p.restFor(_withCategory(ExerciseCategory.highRep, rest: 45)), 45);
    expect(
      p
          .copyWith(restByCategory: false)
          .restFor(_withCategory(ExerciseCategory.heavyCompound)),
      90,
    );
  });

  test('new profile fields round-trip and default sensibly', () {
    const p = Profile();
    expect(p.repRange, (min: 8, max: 12));
    final changed = p.copyWith(
      repRangeMin: 6,
      repRangeMax: 10,
      restByCategory: false,
    );
    final back = Profile.fromJson(changed.toJson());
    expect(
      (back.repRangeMin, back.repRangeMax, back.restByCategory),
      (6, 10, false),
    );
    // Older profiles without the fields.
    final old = Profile.fromJson(const {'name': 'x'});
    expect(
      (old.repRangeMin, old.repRangeMax, old.restByCategory),
      (8, 12, true),
    );
    // Someone who had set their own rest keeps it.
    final own = Profile.fromJson(const {'defaultRestSeconds': 30});
    expect(own.restByCategory, isFalse);
  });

  test('the max of the rep range never goes below the min', () {
    final p = const Profile().copyWith(repRangeMin: 15);
    expect(p.repRangeMax, 15);
  });
}
