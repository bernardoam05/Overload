/// Core vocabulary of the training domain.
library;

enum Muscle {
  chest('Peito'),
  back('Costas'),
  traps('Trapézio'),
  lowerBack('Lombar'),
  shoulders('Deltoide anterior'),
  sideDelts('Deltoide lateral'),
  rearDelts('Deltoide posterior'),
  biceps('Bíceps'),
  triceps('Tríceps'),
  forearms('Antebraços'),
  quads('Quadríceps'),
  hamstrings('Posteriores'),
  glutes('Glúteos'),
  adductors('Adutores'),
  calves('Gémeos'),
  core('Core'),
  obliques('Oblíquos'),
  fullBody('Corpo inteiro'),
  cardio('Cardio');

  const Muscle(this.label);
  final String label;

  /// The rank group this muscle contributes to, if any.
  RankGroup? get rankGroup => switch (this) {
    Muscle.chest => RankGroup.chest,
    Muscle.back || Muscle.traps => RankGroup.back,
    Muscle.shoulders ||
    Muscle.sideDelts ||
    Muscle.rearDelts => RankGroup.shoulders,
    Muscle.biceps => RankGroup.biceps,
    Muscle.triceps => RankGroup.triceps,
    Muscle.quads => RankGroup.quads,
    Muscle.hamstrings ||
    Muscle.glutes ||
    Muscle.lowerBack => RankGroup.posterior,
    _ => null,
  };
}

enum Equipment {
  barbell('Barra'),
  ezBar('Barra EZ'),
  dumbbell('Halteres'),
  machine('Máquina'),
  smith('Máquina Smith'),
  cable('Polia'),
  bodyweight('Peso corporal'),
  kettlebell('Kettlebell'),
  band('Elástico'),
  other('Outro');

  const Equipment(this.label);
  final String label;
}

/// Kind of lift, which sets the default rest and rep range.
enum ExerciseCategory {
  /// Big multi-joint lifts loaded heavy (squat, deadlift, bench press).
  heavyCompound('Composto pesado', 150),

  /// Other multi-joint lifts (rows, presses, leg press, lunges).
  compound('Composto', 120),

  /// Single-joint lifts (curls, extensions, flyes).
  isolation('Isolamento', 75),

  /// Small muscles that respond well to more reps (calves, abs, lateral
  /// raises, adductors and abductors).
  highRep('Reps altas', 60);

  const ExerciseCategory(this.label, this.restSeconds);
  final String label;

  /// Default rest between sets.
  final int restSeconds;
}

/// How an exercise felt technically, rated at the end of it.
enum FormRating {
  bad('Má'),
  ok('OK'),
  good('Boa');

  const FormRating(this.label);
  final String label;
}

/// Body measurements tracked besides body weight, in centimetres.
enum Measurement {
  waist('Cintura'),
  hips('Anca'),
  chest('Peito'),
  shoulders('Ombros'),
  arm('Braço'),
  forearm('Antebraço'),
  thigh('Coxa'),
  calf('Gémeo'),
  neck('Pescoço'),
  bodyFat('Gordura corporal');

  const Measurement(this.label);
  final String label;

  /// Unit shown next to the value.
  String get unit => this == Measurement.bodyFat ? '%' : 'cm';
}

/// How the load is held, so the logged weight is unambiguous.
enum LoadMode {
  /// Both sides move together under one load: a barbell, a machine, or a
  /// single dumbbell held with both hands. The weight is the total load.
  bilateral('Os dois lados juntos', 'Peso total'),

  /// One dumbbell (or handle) in each hand, both working at the same time.
  /// The weight is that of each dumbbell.
  perHand('Um em cada mão', 'Peso de cada haltere'),

  /// One arm or leg at a time. The weight and reps are per side.
  unilateral('Um lado de cada vez', 'Peso e reps por lado');

  const LoadMode(this.label, this.weightMeaning);
  final String label;
  final String weightMeaning;
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
