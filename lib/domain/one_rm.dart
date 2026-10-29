/// Reps above this are too unreliable to estimate a 1RM from.
const maxRepsForEstimate = 15;

/// Epley estimate of the one-rep max, with reps capped at
/// [maxRepsForEstimate].
double estimateOneRepMax(double weight, int reps) {
  if (weight <= 0 || reps <= 0) return 0;
  if (reps == 1) return weight;
  final r = reps > maxRepsForEstimate ? maxRepsForEstimate : reps;
  return weight * (1 + r / 30);
}

/// Weight that can be lifted for [reps] given a one-rep max (inverse Epley).
double weightForReps(double oneRepMax, int reps) {
  if (reps <= 1) return oneRepMax;
  return oneRepMax / (1 + reps / 30);
}

/// Plates per side to load [target] on a bar of [barWeight]. Returns the
/// plates used and the remainder that could not be loaded.
({List<double> plates, double remainder}) platesPerSide(
  double target,
  double barWeight,
  List<double> available,
) {
  final sorted = [...available]..sort((a, b) => b.compareTo(a));
  var perSide = (target - barWeight) / 2;
  final plates = <double>[];
  if (perSide <= 0) return (plates: plates, remainder: 0);
  for (final plate in sorted) {
    while (perSide + 1e-9 >= plate) {
      plates.add(plate);
      perSide -= plate;
    }
  }
  return (plates: plates, remainder: perSide < 1e-6 ? 0 : perSide * 2);
}
