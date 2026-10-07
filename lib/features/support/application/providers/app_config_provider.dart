import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/connectivity/connectivity_monitor.dart';
import '../../../common/cached/application/providers/cached_controller.dart';
import '../../../common/cached/application/states/cached_state.dart';
import '../../domain/entities/app_config.dart';
import 'support_provider.dart';

/// `GET /shared/app-config` (§3.1), read once at launch and kept for the life
/// of the app.
///
/// **Not** autoDispose: the OTP length, feature flags, support contacts and
/// legal versions are read from many screens, and the config must survive
/// every one of them leaving the tree. Public endpoint, so it works before
/// sign-in — bootstrap should `ref.read(appConfigProvider)` once so the fetch
/// starts at launch rather than on the first screen that happens to need it.
///
/// Every derived provider below falls back to [AppConfig.fallback] while the
/// first read is in flight, so nothing downstream has to handle "no config".
final appConfigProvider =
    StateNotifierProvider<CachedController<AppConfig>, CachedState<AppConfig>>((
      ref,
    ) {
      final repository = ref.watch(supportContentRepositoryProvider);
      return CachedController<AppConfig>(
        ({required forceRefresh}) =>
            repository.appConfig(forceRefresh: forceRefresh),
        reconnects: ref.watch(connectivityMonitorProvider).onReconnect,
      );
    });

/// The config value, or the fallback while nothing has loaded.
final appConfigValueProvider = Provider<AppConfig>(
  (ref) =>
      ref.watch(appConfigProvider.select((s) => s.value)) ?? AppConfig.fallback,
);

/// `otp_length` — build the OTP boxes from this.
final otpLengthProvider = Provider<int>(
  (ref) => ref.watch(appConfigValueProvider.select((c) => c.otpLength)),
);

/// `dsr_cooling_off_days` — the days a deleted account can still be
/// reactivated, for the Delete-account wording. The platform default (30)
/// until the server publishes the setting.
final deletionCoolingOffDaysProvider = Provider<int>(
  (ref) =>
      ref.watch(
        appConfigValueProvider.select((c) => c.deletionCoolingOffDays),
      ) ??
      AppConfig.defaultDeletionCoolingOffDays,
);

/// `upload_max_bytes` — the largest file the server accepts, for the upload
/// check before sending and the "up to … MB" wording. The platform default
/// (10 MB) until the server publishes the setting.
final uploadMaxBytesProvider = Provider<int>(
  (ref) =>
      ref.watch(appConfigValueProvider.select((c) => c.uploadMaxBytes)) ??
      AppConfig.defaultUploadMaxBytes,
);

/// `support_contacts` — `{}` when the server has none configured.
final supportContactsProvider = Provider<SupportContacts>(
  (ref) => ref.watch(appConfigValueProvider.select((c) => c.supportContacts)),
);

/// `legal_versions` — slug → current published version.
final legalVersionsProvider = Provider<Map<String, int>>(
  (ref) => ref.watch(appConfigValueProvider.select((c) => c.legalVersions)),
);

/// One `feature_flags_public` switch. False until the config has loaded and
/// for any flag the server does not send.
final publicFeatureFlagProvider = Provider.family<bool, String>(
  (ref, flag) => ref.watch(appConfigValueProvider.select((c) => c.flag(flag))),
);
