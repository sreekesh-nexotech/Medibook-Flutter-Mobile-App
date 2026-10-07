import 'dart:io';

import '../../../../../core/storage/session_files.dart';

/// Writes a downloaded `calendar.ics` to the session temp folder (deleted at
/// sign-out, [SessionFiles]) so it can be handed to the OS ("Add to
/// calendar", §10.10).
///
/// The only file-system touch in the appointments feature, kept in a local
/// data source per the layer rules. The repository returns the saved path and
/// the screen hands it to the OS share sheet (`share_plus`).
abstract interface class CalendarLocalDataSource {
  /// Saves [bytes] as `<bookingRef>.ics` and returns the absolute path.
  Future<String> save(String fileStem, List<int> bytes);
}

class CalendarLocalDataSourceImpl implements CalendarLocalDataSource {
  const CalendarLocalDataSourceImpl({Future<Directory> Function()? directory})
    : _directory = directory ?? SessionFiles.directory;

  final Future<Directory> Function() _directory;

  @override
  Future<String> save(String fileStem, List<int> bytes) async {
    final dir = await _directory();
    final safeStem = fileStem.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final file = File('${dir.path}${Platform.pathSeparator}$safeStem.ics');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }
}
