/// Core vocabulary of the training domain.
library;

enum Muscle {
  chest('Peito'),
  back('Costas'),
  shoulders('Ombros'),
  biceps('Bíceps'),
  triceps('Tríceps'),
  forearms('Antebraços'),
  quads('Quadríceps'),
  hamstrings('Posteriores'),
  glutes('Glúteos'),
  adductors('Adutores'),
  calves('Gémeos'),
  core('Core'),
  fullBody('Corpo inteiro'),
  cardio('Cardio');

  const Muscle(this.label);
  final String label;

  /// The rank group this muscle contributes to, if any.
  RankGroup? get rankGroup => switch (this) {
    Muscle.chest => RankGroup.chest,
    Muscle.back => RankGroup.back,
    Muscle.shoulders => RankGroup.shoulders,
    Muscle.biceps => RankGroup.biceps,
    Muscle.triceps => RankGroup.triceps,
    Muscle.quads => RankGroup.quads,
    Muscle.hamstrings || Muscle.glutes => RankGroup.posterior,
    _ => null,
  };
}

enum Equipment {
  barbell('Barra'),
  dumbbell('Halteres'),
  machine('Máquina'),
  cable('Polia'),
  bodyweight('Peso corporal'),
  kettlebell('Kettlebell'),
  band('Elástico'),
  other('Outro');

  const Equipment(this.label);
  final String label;
}

/// How a set of this exercise is measured.
enum ExerciseKind {
  /// External load × reps.
  weighted('Peso e repetições'),

  /// Body weight + optional added load × reps.
  bodyweight('Peso corporal e repetições'),

  /// Time held, stored in the reps column as seconds.
  duration('Duração'),

  /// Machine-assisted body-weight exercise; the weight column stores the
  /// assistance, so the effective load is body weight minus it.
  assisted('Assistido (peso de ajuda)');

  const ExerciseKind(this.label);
  final String label;
}

enum SetType {
  normal('Normal', ''),
  warmup('Aquecimento', 'A'),
  drop('Drop set', 'D'),
  failure('Até à falha', 'F');

  const SetType(this.label, this.short);
  final String label;
  final String short;

  /// Warm-up sets don't count towards volume, records or ranks.
  bool get isWorking => this != SetType.warmup;
}

enum RankGroup {
  chest('Peito', 'Supino reto'),
  back('Costas', 'Remada curvada'),
  shoulders('Ombros', 'Press militar'),
  biceps('Bíceps', 'Curl com barra'),
  triceps('Tríceps', 'Supino pega fechada'),
  quads('Pernas', 'Agachamento'),
  posterior('Posterior', 'Peso morto');

  const RankGroup(this.label, this.benchmark);
  final String label;

  /// Name of the reference lift the strength standards are expressed in.
  final String benchmark;
}

enum Sex {
  male('Masculino'),
  female('Feminino'),
  unspecified('Prefiro não dizer');

  const Sex(this.label);
  final String label;
}

enum WeightUnit {
  kg('kg'),
  lb('lb');

  const WeightUnit(this.label);
  final String label;
}
