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

  RankGroup? get rankGroup =>
      rankFactor == null ? null : primaryMuscle.rankGroup;

  bool get usesWeight => kind != ExerciseKind.duration;
}
