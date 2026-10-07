import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/storage/session_files.dart';
import 'package:medibook/features/appointments/infrastructure/data_sources/local/calendar_local_ds.dart';

/// QA Prompt 2 (CL CODE-010): calendar files do not outlive the session.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('medibook_session_test');
    SessionFiles.temporaryDirectory = () async => temp;
  });
  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test('an .ics export is deleted at sign-out', () async {
    final path = await const CalendarLocalDataSourceImpl().save(
      'LKSB-2610-00204',
      'BEGIN:VCALENDAR'.codeUnits,
    );
    expect(File(path).existsSync(), isTrue);
    expect(path, contains('${Platform.pathSeparator}session'));

    await SessionFiles.clear();

    expect(File(path).existsSync(), isFalse);
  });

  test('clearing with nothing saved is fine', () async {
    await SessionFiles.clear();
  });
}
