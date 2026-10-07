/// A size limit as people read it: "10 MB", "1.5 MB", "512 KB".
///
/// For the upload limit, which is the server's setting
/// (`upload_max_bytes`) and may not be a round number. Whole megabytes drop
/// the decimal.
String formatSizeLimit(int bytes) {
  const kilobyte = 1024;
  const megabyte = 1024 * 1024;
  if (bytes >= megabyte) {
    final megabytes = bytes / megabyte;
    return megabytes == megabytes.roundToDouble()
        ? '${megabytes.round()} MB'
        : '${megabytes.toStringAsFixed(1)} MB';
  }
  if (bytes >= kilobyte) return '${(bytes / kilobyte).round()} KB';
  return '$bytes B';
}
