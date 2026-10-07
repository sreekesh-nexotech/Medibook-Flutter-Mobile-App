import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/features/app_update/domain/entities/app_update_offer.dart';
import 'package:medibook/features/app_update/domain/entities/app_update_policy.dart';

void main() {
  const both = AppUpdateOffer(
    isAvailable: true,
    immediateAllowed: true,
    flexibleAllowed: true,
  );

  group('compareVersions', () {
    test('compares segments numerically, not as text', () {
      expect(AppUpdatePolicy.compareVersions('1.10.0', '1.9.3'), 1);
      expect(AppUpdatePolicy.compareVersions('1.2.3', '1.2.4'), -1);
      expect(AppUpdatePolicy.compareVersions('2.0.0', '2.0.0'), 0);
    });

    test('pads missing segments and ignores build and pre-release tags', () {
      expect(AppUpdatePolicy.compareVersions('1.2', '1.2.0'), 0);
      expect(AppUpdatePolicy.compareVersions('1.2.0+45', '1.2.0'), 0);
      expect(AppUpdatePolicy.compareVersions('1.3.0-beta', '1.2.9'), 1);
    });
  });

  group('isBelowMinimum', () {
    test('true only when the install is older than the minimum', () {
      expect(AppUpdatePolicy.isBelowMinimum('1.0.0', '1.1.0'), isTrue);
      expect(AppUpdatePolicy.isBelowMinimum('1.1.0', '1.1.0'), isFalse);
      expect(AppUpdatePolicy.isBelowMinimum('1.2.0', '1.1.0'), isFalse);
    });

    test('an unknown version never forces an update', () {
      expect(AppUpdatePolicy.isBelowMinimum(null, '1.1.0'), isFalse);
      expect(AppUpdatePolicy.isBelowMinimum('1.0.0', null), isFalse);
      expect(AppUpdatePolicy.isBelowMinimum('1.0.0', ' '), isFalse);
    });
  });

  group('decide', () {
    AppUpdateKind? decide(
      AppUpdateOffer offer, {
      String? installed = '1.0.0',
      String? minimum,
    }) => AppUpdatePolicy.decide(
      offer: offer,
      installedVersion: installed,
      minVersion: minimum,
    );

    test('nothing available means nothing to do', () {
      expect(decide(AppUpdateOffer.none, minimum: '9.0.0'), isNull);
    });

    test('below the minimum takes the immediate flow', () {
      expect(decide(both, minimum: '1.1.0'), AppUpdateKind.immediate);
    });

    test('at or above the minimum, or with none set, stays flexible', () {
      expect(decide(both, minimum: '1.0.0'), AppUpdateKind.flexible);
      expect(decide(both), AppUpdateKind.flexible);
    });

    test('a mandatory update falls back to flexible when immediate is not '
        'allowed', () {
      const flexibleOnly = AppUpdateOffer(
        isAvailable: true,
        flexibleAllowed: true,
      );
      expect(decide(flexibleOnly, minimum: '1.1.0'), AppUpdateKind.flexible);
    });

    test('an optional update is never forced through the immediate flow', () {
      const immediateOnly = AppUpdateOffer(
        isAvailable: true,
        immediateAllowed: true,
      );
      expect(decide(immediateOnly), isNull);
    });
  });
}
