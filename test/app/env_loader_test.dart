import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/app/bootstrap/env_loader.dart';

/// Checklist ENV-002 / INS-007 (KB-07): a production build must not talk to
/// the integration server, whose address is a bare IP.
void main() {
  test('a bare IP address is refused for production', () {
    expect(
      EnvLoader.productionHostProblem('https://62.171.151.149:8443'),
      contains('IP address'),
    );
    expect(EnvLoader.productionHostProblem('https://[::1]:8443'), isNotNull);
  });

  test('a named host is accepted', () {
    expect(EnvLoader.productionHostProblem('https://api.medibook.in'), isNull);
  });
}
