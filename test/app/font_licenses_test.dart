import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/app/bootstrap/app_bootstrap.dart';

/// Checklist REL-026: the bundled fonts' OFL licences are on the licence page.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Poppins and Inter licences are registered with their copyright',
    () async {
      registerFontLicenses();
      final entries = await LicenseRegistry.licenses.toList();
      String textFor(String family) => entries
          .firstWhere((e) => e.packages.contains(family))
          .paragraphs
          .map((p) => p.text)
          .join('\n');

      expect(textFor('Poppins'), contains('The Poppins Project Authors'));
      expect(textFor('Poppins'), contains('SIL OPEN FONT LICENSE Version 1.1'));
      expect(textFor('Inter'), contains('The Inter Project Authors'));
    },
  );
}
