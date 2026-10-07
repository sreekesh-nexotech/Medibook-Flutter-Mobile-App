import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/app/di/dependencies.dart';
import 'package:medibook/app/di/auth_dependencies.dart';
import 'package:medibook/app/bootstrap/hive_init.dart';
import 'package:medibook/core/network/network_exceptions.dart';
import 'package:medibook/features/auth/infrastructure/data_sources/remote/auth_api.dart';
import 'package:medibook/features/auth/application/providers/verify_controller.dart';
import 'package:medibook/features/auth/application/providers/verify_request.dart';

/// The generic verify screen (`/verify`) only ever accepts a code the server
/// has checked.
void main() {
  late ProviderContainer container;
  late _RejectingAuthApi api;

  setUp(() {
    HiveInit.store = InMemoryLocalStore();
    api = _RejectingAuthApi();
    container = ProviderContainer(
      overrides: [...appDependencies(), authApiProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
  });

  VerifyFormController form() {
    container.listen(verifyFormControllerProvider, (_, _) {});
    return container.read(verifyFormControllerProvider.notifier);
  }

  // BL-AUTH-021: opened without a code request.
  test('without a code request it says the request expired', () async {
    final request = VerifyRequest.fromQuery(const {});
    expect(request.isOrphan, isTrue);

    expect(await form().verify(request: request, code: '1234'), isFalse);
    expect(
      container.read(verifyFormControllerProvider).failure?.userMessage,
      'This code request has expired. Go back and ask for a new code.',
    );
    expect(api.verifyCalls, 0);
  });

  // BL-AUTH-022: there is no phone-change purpose here any more; an old link
  // carrying one is checked by the server like any other code, and a made-up
  // code is refused.
  test('a phone-change link does not accept a made-up code', () async {
    final request = VerifyRequest.fromQuery(const {
      'purpose': 'phone-change',
      'ch': 'x',
      'len': '4',
    });
    expect(
      VerifyPurpose.values.map((p) => p.slug),
      isNot(contains('phone-change')),
    );

    expect(await form().verify(request: request, code: '1234'), isFalse);
    expect(api.verifyCalls, 1, reason: 'the server was asked');
  });
}

class _RejectingAuthApi implements AuthApi {
  int verifyCalls = 0;

  Never _reject() {
    verifyCalls++;
    throw const HttpStatusException(
      statusCode: 400,
      code: ApiErrorCodes.authOtpInvalid,
      serverMessage: 'That code is not right.',
    );
  }

  @override
  Future<Map<String, Object?>> verifyPasswordReset({
    required String challengeId,
    required String code,
  }) async => _reject();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
