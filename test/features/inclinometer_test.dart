import 'package:flutter_test/flutter_test.dart';
import 'package:overload/domain/exercise.dart';
import 'package:overload/features/tools/inclinometer.dart';

void main() {
  test('incline from gravity: flat, inclined, declined', () {
    expect(inclineDegrees(0, 9.81), closeTo(0, 1e-9));
    // 30°: gravity splits into sin/cos along the phone's y and z axes.
    expect(inclineDegrees(4.905, 8.4957), closeTo(30, 0.01));
    expect(inclineDegrees(-2.539, 9.476), closeTo(-15, 0.01));
    expect(inclineDegrees(9.81, 0), closeTo(90, 1e-9));
  });

  test('closest bench position', () {
    expect(closestBenchPosition(32), 30);
    expect(closestBenchPosition(41), 45);
    expect(closestBenchPosition(-12), -15);
  });

  test('angle labels', () {
    expect(formatAngle(0), '0° (plano)');
    expect(formatAngle(30), '30°');
    expect(formatAngle(-15), '-15° (declinado)');
  });
}
