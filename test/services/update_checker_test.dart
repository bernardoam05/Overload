import 'package:flutter_test/flutter_test.dart';
import 'package:overload/services/update_checker.dart';

void main() {
  parseTests();
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

void parseTests() {
  group('UpdateChecker.parseRelease', () {
    final release = {
      'tag_name': 'v1.2.0',
      'html_url': 'https://github.com/x/y/releases/tag/v1.2.0',
      'assets': [
        {'name': 'overload-v1.2.0-arm64-v8a.apk', 'browser_download_url': 'https://dl/arm64'},
        {'name': 'overload-v1.2.0-armeabi-v7a.apk', 'browser_download_url': 'https://dl/v7a'},
        {'name': 'SHA256SUMS.txt', 'browser_download_url': 'https://dl/sums'},
      ],
    };

    test('collects APKs per ABI and the checksums file', () {
      final info = UpdateChecker.parseRelease(release, '1.0.0')!;
      expect(info.version, '1.2.0');
      expect(info.apks, {'arm64-v8a': 'https://dl/arm64', 'armeabi-v7a': 'https://dl/v7a'});
      expect(info.checksumsUrl, 'https://dl/sums');
    });

    test('returns null when not newer or malformed', () {
      expect(UpdateChecker.parseRelease(release, '1.2.0'), isNull);
      expect(UpdateChecker.parseRelease({'tag_name': 1}, '1.0.0'), isNull);
    });
  });
}
