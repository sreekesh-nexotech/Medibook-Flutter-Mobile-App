import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/app/router/app_routes.dart';

/// UB-13: there is no reschedule — "Book Again" / "Rebook" is the way back
/// in, so it must land where the patient can pick a new time for the same
/// doctor (step 2), never on step 3 without a slot ("Pick a doctor and a
/// time first").
void main() {
  test('rebook opens the Doctor & time step with the doctor chosen', () {
    final uri = Uri.parse(
      AppRoutes.rebookPath(dept: 'general-medicine', doctor: 'doc-1'),
    );
    expect(uri.path, AppRoutes.booking);
    expect(uri.queryParameters, {
      'step': '2',
      'origin': 'appointments',
      'dept': 'general-medicine',
      'doctor': 'doc-1',
    });
  });
}
