/// Supersets: consecutive exercises done back to back, linked by a
/// "superset with the next one" flag on each exercise. A flag on the last
/// exercise links to nothing and is ignored.
library;

/// Group number (0, 1, 2… in order) of each exercise that belongs to a
/// superset, or `null` for exercises done on their own.
List<int?> supersetGroups(List<bool> linksToNext) {
  final n = linksToNext.length;
  final result = List<int?>.filled(n, null);
  var group = -1;
  for (var i = 0; i < n; i++) {
    final linkedBefore = i > 0 && linksToNext[i - 1];
    final linkedAfter = linksToNext[i] && i < n - 1;
    if (!linkedBefore && linkedAfter) group++;
    if (linkedBefore || linkedAfter) result[i] = group;
  }
  return result;
}

/// "A", "B"… for superset group [group].
String supersetLetter(int group) =>
    String.fromCharCode('A'.codeUnitAt(0) + group % 26);

/// Whether exercise [i] hands over to the next one without resting: it is
/// linked to it and that exercise still has sets to do.
bool continuesSuperset(List<bool> linksToNext, List<bool> hasPending, int i) =>
    i >= 0 && i < linksToNext.length - 1 && linksToNext[i] && hasPending[i + 1];
