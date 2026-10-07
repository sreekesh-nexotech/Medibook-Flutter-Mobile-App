import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/utils/validators.dart';

/// The sign-up and profile field rules (Checklist AUTH-003, -006, -007,
/// -008, -010).
void main() {
  group('mobile number (AUTH-003)', () {
    test('rejects empty, short, long and 0-5 starts', () {
      expect(Validators.phone(''), 'Enter your mobile number');
      expect(Validators.phone('980868325'), 'Mobile number must be 10 digits');
      expect(
        Validators.phone('98086832571'),
        'Mobile number must be 10 digits',
      );
      for (final start in ['0', '1', '2', '3', '4', '5']) {
        expect(
          Validators.phone('${start}808683257'),
          'Mobile number must start with 6-9',
        );
      }
    });

    test('accepts a valid number typed with spaces or dashes', () {
      expect(Validators.phone('98086 83257'), isNull);
      expect(Validators.phone('980-868-3257'), isNull);
    });
  });

  group('email (AUTH-006)', () {
    test('rejects malformed addresses', () {
      for (final bad in ['abc', 'a@b', 'a b@c.com']) {
        expect(Validators.email(bad), isNotNull, reason: bad);
      }
      expect(Validators.email('sanjay@example.com'), isNull);
    });
  });

  group('password (AUTH-007 / AUTH-008)', () {
    test('ten characters is the minimum', () {
      expect(Validators.password('abcdef', min: 10), 'At least 10 characters');
      expect(
        Validators.password('abcdefghi', min: 10),
        'At least 10 characters',
      );
      expect(Validators.password('abcdefghij', min: 10), isNull);
    });

    test('confirmation must match', () {
      expect(
        Validators.confirmPassword('abcdefghij', 'abcdefghik'),
        'Passwords do not match',
      );
      expect(Validators.confirmPassword('abcdefghij', 'abcdefghij'), isNull);
    });
  });

  group('person name (UI-009)', () {
    test('letters of any script, with marks, spaces and hyphens', () {
      for (final ok in [
        'Anita',
        "D'Souza",
        'Anne-Marie',
        'ശ്രീലക്ഷ്മി',
        'वर्मा',
        'Ćosić',
      ]) {
        expect(Validators.personName(ok), isNull, reason: ok);
      }
    });

    test('digits, symbols and emoji are refused', () {
      for (final bad in ['Anita2', 'An1ta', 'Sanjay🌸', '<b>', '-Anita']) {
        expect(Validators.personName(bad), 'Use letters only', reason: bad);
      }
      expect(Validators.personName('A'), 'Name is too short');
    });
  });

  group('PIN code (AUTH-010)', () {
    test('six digits, not starting with 0', () {
      expect(Validators.pincode('68202'), isNotNull);
      expect(Validators.pincode('082020'), isNotNull);
      expect(Validators.pincode('682020'), isNull);
    });
  });
}
