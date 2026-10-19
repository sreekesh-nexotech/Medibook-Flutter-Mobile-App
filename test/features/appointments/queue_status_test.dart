import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/features/appointments/domain/entities/queue_status.dart';

/// UAT 16 Oct: after the desk pressed "Done" the server kept
/// `current_token_no` but cleared the label, and the patient still read
/// "You are being seen".
void main() {
  QueueStatus queue({String? current, int? currentNo}) => QueueStatus(
    sessionState: SessionState.open,
    queueState: QueueState.available,
    tokensAhead: 0,
    estimatedWaitMinutes: 0,
    updatedAt: DateTime(2026, 10, 16),
    currentToken: current,
    currentTokenNo: currentNo,
    yourToken: 'A002',
    yourTokenNo: 2,
  );

  test('being seen while this token is on the desk', () {
    expect(queue(current: 'A002', currentNo: 2).isBeingSeen, isTrue);
  });

  test('not being seen once the desk cleared the token', () {
    expect(queue(currentNo: 2).isBeingSeen, isFalse);
  });

  test('not being seen while another token is called', () {
    expect(queue(current: 'A003', currentNo: 3).isBeingSeen, isFalse);
  });
}
