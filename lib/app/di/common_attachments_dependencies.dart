import '../../features/auth/application/providers/auth_provider.dart';
import '../../features/common/attachments/application/providers/attachments_provider.dart';
import '../../features/common/attachments/infrastructure/data_sources/local/file_picker_ds.dart';
import '../../features/common/attachments/infrastructure/data_sources/remote/files_api.dart';
import '../../features/common/attachments/infrastructure/data_sources/remote/storage_uploader.dart';
import '../../features/common/attachments/infrastructure/repositories/file_upload_service_impl.dart';
import '../../features/common/attachments/infrastructure/repositories/file_url_resolver_impl.dart';
import '../../features/support/application/providers/app_config_provider.dart';
import '../config/env.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Dependency wiring for features/common/attachments: the concrete data sources and
// repositories behind this feature's domain contracts (QA architecture
// audit #5, CL CODE-014). Only app/ imports infrastructure/.

/// `/shared/files` over the app's [ApiClient].
final filesApiProvider = Provider<FilesApi>(
  (ref) => HttpFilesApi(ref.watch(apiClientProvider)),
);

/// The plain HTTP client for the presigned PUT — deliberately **not** the
/// `ApiClient`, which would add the bearer token and the API base URL.
final storageUploaderProvider = Provider<StorageUploader>(
  (ref) => DioStorageUploader(
    allowBadCertificate: Env.allowBadCertificate && !Env.isProd,
  ),
);

/// The platform file / image picker.
final filePickerDataSourceProvider = Provider<FilePickerDataSource>(
  (ref) => PlatformFilePickerDataSource(),
);

/// Overrides that put the real implementations behind this feature's
/// application-layer providers. Applied once, at the root `ProviderScope`.
final List<Override> commonAttachmentsDependencies = [
  fileUploadServiceProvider.overrideWith(
    (ref) => FileUploadServiceImpl(
      api: ref.watch(filesApiProvider),
      storage: ref.watch(storageUploaderProvider),
      picker: ref.watch(filePickerDataSourceProvider),
      // The server's cap as app-config has it now, not a number in the app.
      limitBytes: () => ref.read(uploadMaxBytesProvider),
    ),
  ),
  fileUrlResolverProvider.overrideWith(
    (ref) => FileUrlResolverImpl(api: ref.watch(filesApiProvider)),
  ),
];
