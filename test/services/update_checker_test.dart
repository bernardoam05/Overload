import 'package:flutter_test/flutter_test.dart';
import 'package:overload/services/update_checker.dart';

void main() {
  group('UpdateChecker.isNewer', () {
    test('compares major, minor and patch numerically', () {
      expect(UpdateChecker.isNewer('1.0.1', '1.0.0'), isTrue);
      expect(UpdateChecker.isNewer('1.10.0', '1.9.9'), isTrue);
      expect(UpdateChecker.isNewer('2.0.0', '1.99.99'), isTrue);
    });

    test('equal or older is not an update', () {
      expect(UpdateChecker.isNewer('1.0.0', '1.0.0'), isFalse);
      expect(UpdateChecker.isNewer('1.0.0', '1.0.1'), isFalse);
    });

    test('ignores build number and malformed versions', () {
      expect(UpdateChecker.isNewer('1.0.1', '1.0.0+7'), isTrue);
      expect(UpdateChecker.isNewer('abc', '1.0.0'), isFalse);
      expect(UpdateChecker.isNewer('1.0', '1.0.0'), isFalse);
    });
  });
}
