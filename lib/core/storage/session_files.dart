import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../utils/logger.dart';

/// Temporary files that belong to the signed-in patient — calendar `.ics`
/// exports today. They live in one folder under the app's temp directory so
/// sign-out can delete them all (QA Prompt 2, CL CODE-010).
abstract final class SessionFiles {
  SessionFiles._();

  static const String _folder = 'session';

  /// Overridable in tests.
  static Future<Directory> Function() temporaryDirectory =
      getTemporaryDirectory;

  /// The session folder, created when missing.
  static Future<Directory> directory() async {
    final root = await temporaryDirectory();
    return Directory(
      '${root.path}${Platform.pathSeparator}$_folder',
    ).create(recursive: true);
  }

  /// Deletes the session folder, and the copies the file picker made of
  /// documents the patient chose to upload. Never throws: sign-out must
  /// finish even if a file is busy.
  static Future<void> clear() async {
    try {
      final root = await temporaryDirectory();
      final dir = Directory('${root.path}${Platform.pathSeparator}$_folder');
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (error) {
      AppLogger.warning(
        'Could not delete session files',
        name: 'storage',
        error: error,
      );
    }
    try {
      await FilePicker.clearTemporaryFiles();
    } catch (_) {
      // Not supported on every platform, and absent in tests.
    }
  }
}
