import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/network/user_agent.dart';

/// The User-Agent names the build and the phone, so Signed-in Devices can
/// tell one session from another (§4.9).
void main() {
  group('format', () {
    test('product, version, then the device and OS in brackets', () {
      expect(
        AppUserAgent.format(
          version: '1.0.0',
          device: 'Google Pixel 7',
          os: 'Android 14',
        ),
        'Medibook/1.0.0 (Google Pixel 7; Android 14)',
      );
    });

    test('leaves out what could not be read', () {
      expect(AppUserAgent.format(version: '1.0.0'), 'Medibook/1.0.0');
      expect(
        AppUserAgent.format(version: '1.0.0', os: 'iOS 17.2'),
        'Medibook/1.0.0 (iOS 17.2)',
      );
      expect(AppUserAgent.format(), AppUserAgent.fallback);
    });

    test('a value cannot break the header structure', () {
      expect(
        AppUserAgent.format(
          version: '1.0.0',
          device: 'Odd (model); name\n',
          os: 'Android 14',
        ),
        'Medibook/1.0.0 (Odd model name; Android 14)',
      );
    });
  });

  group('deviceName', () {
    test('joins maker and model, without repeating the maker', () {
      expect(
        AppUserAgent.deviceName(manufacturer: 'Google', model: 'Pixel 7'),
        'Google Pixel 7',
      );
      expect(
        AppUserAgent.deviceName(manufacturer: 'samsung', model: 'SM-S911B'),
        'Samsung SM-S911B',
      );
      expect(
        AppUserAgent.deviceName(manufacturer: 'Google', model: 'Google Pixel'),
        'Google Pixel',
      );
      expect(
        AppUserAgent.deviceName(manufacturer: 'Apple', model: 'iPhone15,2'),
        'Apple iPhone15,2',
      );
    });

    test('copes with either part missing', () {
      expect(AppUserAgent.deviceName(model: 'Pixel 7'), 'Pixel 7');
      expect(AppUserAgent.deviceName(manufacturer: 'xiaomi'), 'Xiaomi');
      expect(AppUserAgent.deviceName(), isNull);
    });
  });

  test('osName', () {
    expect(AppUserAgent.osName('Android', '14'), 'Android 14');
    expect(AppUserAgent.osName('iOS', null), 'iOS');
    expect(AppUserAgent.osName(null, '14'), isNull);
  });
}
