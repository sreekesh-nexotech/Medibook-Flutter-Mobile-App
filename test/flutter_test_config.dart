import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Test bootstrap that runs before every test file (Flutter auto-detects
/// `flutter_test_config.dart`). It loads the app's bundled fonts into the test
/// engine so **golden images render real Poppins/Inter glyphs** instead of the
/// fallback test font — without this, every golden would show boxes and never
/// match the design.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await _loadFonts();
  await testMain();
}

Future<void> _loadFonts() async {
  const families = <String, List<String>>{
    'Poppins': [
      'assets/fonts/Poppins-Regular.ttf',
      'assets/fonts/Poppins-Medium.ttf',
      'assets/fonts/Poppins-SemiBold.ttf',
      'assets/fonts/Poppins-Bold.ttf',
    ],
    'Inter': [
      'assets/fonts/Inter-Regular.ttf',
    ],
  };

  for (final entry in families.entries) {
    final loader = FontLoader(entry.key);
    for (final path in entry.value) {
      loader.addFont(rootBundle.load(path));
    }
    await loader.load();
  }
}
