import '../../core/storage/cache/cached_fetcher.dart';
import '../../features/auth/application/providers/auth_provider.dart';
import '../../features/profile/application/providers/profile_provider.dart';
import '../../features/profile/infrastructure/data_sources/remote/contacts_api.dart';
import '../../features/profile/infrastructure/data_sources/remote/persons_api.dart';
import '../../features/profile/infrastructure/data_sources/remote/profile_api.dart';
import '../../features/profile/infrastructure/repositories/contacts_repository_impl.dart';
import '../../features/profile/infrastructure/repositories/family_repository_impl.dart';
import '../../features/profile/infrastructure/repositories/profile_repository_impl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Dependency wiring for features/profile: the concrete data sources and
// repositories behind this feature's domain contracts (QA architecture
// audit #5, CL CODE-014). Only app/ imports infrastructure/.

final profileApiProvider = Provider<ProfileApi>(
  (ref) => HttpProfileApi(ref.watch(apiClientProvider)),
);

final personsApiProvider = Provider<PersonsApi>(
  (ref) => HttpPersonsApi(ref.watch(apiClientProvider)),
);

final contactsApiProvider = Provider<ContactsApi>(
  (ref) => HttpContactsApi(ref.watch(apiClientProvider)),
);

/// Overrides that put the real implementations behind this feature's
/// application-layer providers. Applied once, at the root `ProviderScope`.
final List<Override> profileDependencies = [
  profileRepositoryProvider.overrideWith(
    (ref) => ProfileRepositoryImpl(
      api: ref.watch(profileApiProvider),
      fetcher: ref.watch(cachedFetcherProvider),
    ),
  ),
  familyRepositoryProvider.overrideWith(
    (ref) => FamilyRepositoryImpl(
      api: ref.watch(personsApiProvider),
      fetcher: ref.watch(cachedFetcherProvider),
    ),
  ),
  contactsRepositoryProvider.overrideWith(
    (ref) => ContactsRepositoryImpl(
      api: ref.watch(contactsApiProvider),
      fetcher: ref.watch(cachedFetcherProvider),
    ),
  ),
];
