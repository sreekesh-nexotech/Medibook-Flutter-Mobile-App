import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/error/failure.dart';
import 'package:medibook/core/network/network_exceptions.dart';

/// Checklist ERR-006 / ERR-007: what a patient reads for a switched-off
/// feature and for a bare 500.
void main() {
  test('501 NOT_IMPLEMENTED_YET says the feature is not available', () {
    final failure = NetworkExceptions.toFailure(
      const HttpStatusException(statusCode: 501, code: 'NOT_IMPLEMENTED_YET'),
      StackTrace.empty,
    );
    expect(failure, isA<ServerFailure>());
    expect(failure.userMessage, 'That feature is not available right now.');
  });

  // The server's cap is a platform setting; its 413 names it in
  // `meta.max_bytes`, so the patient reads the real limit.
  test('413 FILE_TOO_LARGE names the limit the server sent', () {
    final failure = NetworkExceptions.toFailure(
      const HttpStatusException(
        statusCode: 413,
        code: 'FILE_TOO_LARGE',
        meta: {'max_bytes': 5 * 1024 * 1024},
      ),
      StackTrace.empty,
    );
    expect(failure.userMessage, 'That file is too large. The limit is 5 MB.');

    final withoutLimit = NetworkExceptions.toFailure(
      const HttpStatusException(statusCode: 413, code: 'FILE_TOO_LARGE'),
      StackTrace.empty,
    );
    expect(withoutLimit.userMessage, 'That file is too large.');
  });

  test('a 500 with an HTML or empty body is a generic error', () {
    for (final body in ['<html><body>Server Error</body></html>', null]) {
      final failure = NetworkExceptions.toFailure(
        HttpStatusException.fromBody(500, body, rawBody: body),
        StackTrace.empty,
      );
      expect(failure, isA<ServerFailure>(), reason: '$body');
      expect(failure.userMessage, isNot(contains('html')));
      expect(failure.userMessage, isNot(contains('500')));
    }
  });
}
