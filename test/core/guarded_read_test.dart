import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/error/failure.dart';
import 'package:medibook/core/network/api_client.dart';
import 'package:medibook/core/network/network_exceptions.dart';

/// QA Prompt 3 #1 (CL CODE-011): a provider's read always fails with a
/// typed Failure.
void main() {
  test('passes a value through', () async {
    expect(await guardedRead('x', () async => 42), 42);
  });

  test('turns a raw network error into a Failure', () async {
    await expectLater(
      guardedRead<int>('x', () async => throw const NoConnectionException()),
      throwsA(isA<NetworkFailure>()),
    );
  });

  test('keeps a Failure as it is', () async {
    const failure = NotFoundFailure();
    await expectLater(
      guardedRead<int>('x', () async => throw failure),
      throwsA(same(failure)),
    );
  });
}
