import 'package:intl/intl.dart';

import '../domain/enums.dart';
import '../domain/models.dart';

const _lbPerKg = 2.2046226218;
const locale = 'pt_PT';

double toDisplayWeight(double kg, WeightUnit unit) =>
    unit == WeightUnit.kg ? kg : kg * _lbPerKg;

double fromDisplayWeight(double value, WeightUnit unit) =>
    unit == WeightUnit.kg ? value : value / _lbPerKg;

final _num = NumberFormat('#,##0.##', locale);
final _num1 = NumberFormat('#,##0.#', locale);
final _int = NumberFormat('#,##0', locale);

String formatNumber(num value, {int decimals = 2}) => switch (decimals) {
  0 => _int.format(value),
  1 => _num1.format(value),
  _ => _num.format(value),
};

/// Weight in the user's unit, e.g. `82,5 kg`.
String formatWeight(double kg, WeightUnit unit, {bool withUnit = true}) {
  final v = toDisplayWeight(kg, unit);
  final rounded = (v * 100).round() / 100;
  final text = formatNumber(rounded);
  return withUnit ? '$text ${unit.label}' : text;
}

/// Total volume, abbreviated to tonnes when large.
String formatVolume(double kg, WeightUnit unit) {
  final v = toDisplayWeight(kg, unit);
  if (unit == WeightUnit.kg && v >= 10000) {
    return '${formatNumber(v / 1000, decimals: 1)} t';
  }
  return '${formatNumber(v, decimals: 0)} ${unit.label}';
}

/// Plain number for text fields: no grouping, comma decimal separator.
String editableNumber(double value) {
  final rounded = (value * 100).round() / 100;
  var s = rounded.toStringAsFixed(2);
  s = s.replaceFirst(RegExp(r'\.?0+$'), '');
  return s.replaceAll('.', ',');
}

/// Parses user input accepting both `,` and `.` as decimal separators.
double? parseDecimal(String input) {
  final cleaned = input.trim().replaceAll(' ', '').replaceAll(',', '.');
  if (cleaned.isEmpty) return null;
  final v = double.tryParse(cleaned);
  if (v == null || v.isNaN || v.isInfinite) return null;
  return v;
}

String formatClock(Duration d) {
  if (d.isNegative) d = Duration.zero;
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '${d.inMinutes}:$s';
}

String formatSeconds(int seconds) => formatClock(Duration(seconds: seconds));

String formatDuration(Duration d) {
  if (d.isNegative) d = Duration.zero;
  if (d.inMinutes < 1) return '${d.inSeconds} s';
  if (d.inHours == 0) return '${d.inMinutes} min';
  final m = d.inMinutes.remainder(60);
  return m == 0
      ? '${d.inHours} h'
      : '${d.inHours} h ${m.toString().padLeft(2, '0')}';
}

String formatDate(DateTime d) =>
    DateFormat("EEE, d 'de' MMM", locale).format(d);
String formatDateLong(DateTime d) =>
    DateFormat("EEEE, d 'de' MMMM 'de' y", locale).format(d);
String formatDateShort(DateTime d) => DateFormat('d MMM', locale).format(d);
String formatTime(DateTime d) => DateFormat.Hm(locale).format(d);
String formatMonth(DateTime d) => DateFormat('MMMM y', locale).format(d);

String formatRelativeDay(DateTime d, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final a = DateTime(d.year, d.month, d.day);
  final b = DateTime(today.year, today.month, today.day);
  final diff = b.difference(a).inDays;
  if (diff == 0) return 'Hoje';
  if (diff == 1) return 'Ontem';
  if (diff > 1 && diff < 7) return 'Há $diff dias';
  return formatDate(d);
}

/// Human description of a set, e.g. `80 kg × 8`, `+10 kg × 6`, `1:30`.
String formatSet(SetEntry set, ExerciseKind kind, WeightUnit unit) =>
    switch (kind) {
      ExerciseKind.weighted =>
        '${formatWeight(set.weightKg, unit)} × ${set.reps}',
      ExerciseKind.bodyweight =>
        set.weightKg > 0
            ? '+${formatWeight(set.weightKg, unit)} × ${set.reps}'
            : '${set.reps} reps',
      ExerciseKind.duration => formatSeconds(set.reps),
      ExerciseKind.assisted =>
        set.weightKg > 0
            ? '−${formatWeight(set.weightKg, unit)} × ${set.reps}'
            : '${set.reps} reps',
    };

String capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
