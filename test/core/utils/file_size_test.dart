import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/utils/file_size.dart';

/// The upload limit is the server's setting, so it is worded from bytes
/// rather than written into the app as "10 MB".
void main() {
  test('whole megabytes drop the decimal', () {
    expect(formatSizeLimit(10 * 1024 * 1024), '10 MB');
    expect(formatSizeLimit(1024 * 1024), '1 MB');
  });

  test('other sizes keep one decimal, or fall to KB and B', () {
    expect(formatSizeLimit(1536 * 1024), '1.5 MB');
    expect(formatSizeLimit(512 * 1024), '512 KB');
    expect(formatSizeLimit(900), '900 B');
  });
}
