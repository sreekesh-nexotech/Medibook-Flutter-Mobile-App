import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/error/failure.dart';
import 'package:medibook/core/network/network_exceptions.dart';
import 'package:medibook/features/auth/application/states/auth_state.dart';
import 'package:medibook/features/auth/presentation/components/lockout_notice.dart';

import '../../support/harness.dart';

/// BL-AUTH-032: five failed sign-ins lock the account for one hour (API §4,
/// `423 AUTH_LOCKED_OUT`). The warnings used to say "60 seconds".
void main() {
  Future<void> show(WidgetTester tester, int attemptsLeft) => tester.pumpWidget(
    screenHarness(
      Scaffold(
        body: LockoutNotice(
          state: AuthUnauthenticated(serverAttemptsRemaining: attemptsLeft),
        ),
      ),
    ),
  );

  testWidgets('the warning names the real pause: one hour', (tester) async {
    await show(tester, 2);
    expect(
      find.text('2 attempts left before sign-in is paused for 1 hour.'),
      findsOneWidget,
    );
    expect(find.textContaining('seconds'), findsNothing);
  });

  testWidgets('the last-attempt warning says one hour too', (tester) async {
    await show(tester, 1);
    expect(find.textContaining('pauses sign-in for 1 hour'), findsOneWidget);
  });

  test('durations read as words', () {
    expect(LockoutNotice.durationInWords(const Duration(hours: 1)), '1 hour');
    expect(
      LockoutNotice.durationInWords(const Duration(minutes: 15)),
      '15 minutes',
    );
    expect(
      LockoutNotice.durationInWords(const Duration(seconds: 30)),
      '30 seconds',
    );
  });

  testWidgets('one box says both what went wrong and the attempts left', (
    tester,
  ) async {
    await show(tester, 4);
    expect(
      find.text('That email or number and password do not match'),
      findsOneWidget,
    );
    expect(
      find.text('4 attempts left before sign-in is paused for 1 hour.'),
      findsOneWidget,
    );
    expect(find.text('Sign-in attempts'), findsNothing);
  });

  group('coversFailure (C-A6: no second error box)', () {
    const wrongPassword = UnauthorizedFailure(
      userMessage: 'That email or number and password do not match an account.',
      sessionExpired: false,
      apiCode: ApiErrorCodes.authInvalidCredentials,
    );

    test('a wrong password is covered once attempts are showing', () {
      expect(
        LockoutNotice.coversFailure(
          AuthUnauthenticated(serverAttemptsRemaining: 4),
          wrongPassword,
        ),
        isTrue,
      );
    });

    test('nothing is covered before the first failure', () {
      expect(
        LockoutNotice.coversFailure(const AuthUnauthenticated(), wrongPassword),
        isFalse,
      );
    });

    test('other failures keep their own box', () {
      expect(
        LockoutNotice.coversFailure(
          AuthUnauthenticated(serverAttemptsRemaining: 4),
          const NetworkFailure(),
        ),
        isFalse,
      );
      expect(
        LockoutNotice.coversFailure(
          AuthUnauthenticated(serverAttemptsRemaining: 4),
          null,
        ),
        isFalse,
      );
    });
  });
}
