import 'enums.dart';

/// An exercise from the library (seeded or created by the user).
class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.primaryMuscle,
    required this.secondaryMuscles,
    required this.equipment,
    required this.kind,
    required this.rankFactor,
    required this.instructions,
    required this.isCustom,
    required this.seedKey,
    required this.restSeconds,
    required this.archived,
    this.loadMode = LoadMode.bilateral,
  });

  final int id;
  final String name;
  final Muscle primaryMuscle;
  final List<Muscle> secondaryMuscles;
  final Equipment equipment;
  final ExerciseKind kind;

  /// Multiplier that converts this exercise's estimated 1RM into the
  /// equivalent 1RM of its rank group's benchmark lift. `null` means the
  /// exercise does not count towards ranks.
  final double? rankFactor;
  final String instructions;
  final bool isCustom;
  final String? seedKey;

  /// Rest timer override in seconds; `null` uses the global default.
  final int? restSeconds;
  final bool archived;

  /// How the load is held (see [LoadMode]).
  final LoadMode loadMode;

  RankGroup? get rankGroup =>
      rankFactor == null ? null : primaryMuscle.rankGroup;

  bool get usesWeight => kind != ExerciseKind.duration;

  /// Short explanation of what the logged weight means, or `null` when it is
  /// obvious (a barbell or a machine moved with both sides).
  String? get loadLabel => loadLabelFor(loadMode, equipment);
}

String? loadLabelFor(LoadMode mode, Equipment equipment) {
  final (one, plural) = switch (equipment) {
    Equipment.dumbbell => ('1 haltere', 'haltere'),
    Equipment.kettlebell => ('1 kettlebell', 'kettlebell'),
    _ => (null, null),
  };
  return switch (mode) {
    LoadMode.bilateral =>
      one == null ? null : '$one seguro com as duas mãos',
    LoadMode.perHand =>
      plural == null
          ? 'Um em cada mão · peso de cada lado'
          : 'Um $plural em cada mão · peso de cada',
    LoadMode.unilateral => 'Unilateral · peso e reps por lado',
  };
}
