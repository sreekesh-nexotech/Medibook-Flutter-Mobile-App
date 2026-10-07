import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/app/router/app_routes.dart';
import 'package:medibook/features/booking/presentation/components/slot_labels.dart';

/// Home audit (6 Oct 2026): the banner's server link and the day-first
/// "next free" label.
void main() {
  group('a banner cta_target', () {
    test('our scheme and our web host open in the app', () {
      expect(AppRoutes.inAppPathFor('medibook://booking'), AppRoutes.booking);
      expect(
        AppRoutes.inAppPathFor('https://medibook.app/hospitals'),
        AppRoutes.hospitals,
      );
    });

    test('anyone else\'s link is never read as an app screen', () {
      expect(AppRoutes.inAppPathFor('https://example.com/home'), isNull);
      expect(AppRoutes.inAppPathFor('javascript:alert(1)'), isNull);
      expect(AppRoutes.inAppPathFor(''), isNull);
    });
  });

  group('next free, day first', () {
    test('no slot', () {
      expect(SlotLabels.nextAvailableShort(null), 'No free slot');
    });

    test('tomorrow keeps the day ahead of the time', () {
      final tomorrowNine = DateTime.now().toUtc().add(const Duration(days: 1));
      final label = SlotLabels.nextAvailableShort(
        tomorrowNine,
        timezone: 'Asia/Kolkata',
      );
      expect(label, startsWith('Tomorrow, '));
      expect(label, matches(RegExp(r'\d{1,2}:\d{2} (AM|PM)$')));
    });
  });
}
