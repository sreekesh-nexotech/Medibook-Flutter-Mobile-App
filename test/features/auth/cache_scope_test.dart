import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/features/auth/application/providers/auth_provider.dart';

import '../profile/profile_test_support.dart';

/// The cache is scoped to the signed-in account, not to its access token
/// (DEF-065), and to nobody when signed out.
void main() {
  test('the scope is the account id while signed in, null after', () async {
    final auth = FakeAuthRepository();
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(auth)],
    );
    addTearDown(container.dispose);
    final scope = container.read(cacheScopeProvider);

    expect(await scope(), testUser.id);
    auth.user = null;
    expect(await scope(), isNull);
  });
}
