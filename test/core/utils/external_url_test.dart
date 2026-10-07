import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/utils/external_url.dart';

/// BL-REC-033: when nothing on the device can open a file link the patient
/// must be told. The plugin *throws* in that case on Android, so the helper
/// has to turn a throw into `false` for the screens' "No app on this device
/// could open the file" message to show.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.flutter.io/url_launcher');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('true when the system takes the link', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => true);
    expect(await openExternalUrl('https://files.example/report.pdf'), isTrue);
  });

  test('false, not an exception, when no app can open it', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => throw PlatformException(
        code: 'ACTIVITY_NOT_FOUND',
        message: 'No Activity found to handle intent',
      ),
    );
    expect(await openExternalUrl('nohandler://files/report.pdf'), isFalse);
  });

  test('false when the launcher itself is missing', () async {
    expect(await openExternalUrl('https://files.example/report.pdf'), isFalse);
  });

  test('false for a link that is not a link', () async {
    expect(await openExternalUrl('http://[::1'), isFalse);
  });
}
