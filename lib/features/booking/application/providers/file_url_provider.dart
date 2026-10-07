import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/logger.dart';
import '../../../auth/application/providers/auth_provider.dart';
import '../../../common/attachments/application/providers/attachments_provider.dart';

/// The signed URL for a `*_file_id` (§11.4), or null when it cannot be shown
/// right now — signed out (the endpoint needs a token), offline, or an id
/// the account cannot read. The caller falls back to initials or a tinted
/// placeholder; nothing here throws into a widget.
///
/// Resolution and memoisation live in the shared attachments feature
/// (`fileUrlResolverProvider`); this only adds the signed-out short-circuit
/// and the null-on-failure contract discovery screens want. autoDispose
/// family — file ids are unbounded; the resolver keeps the memo.
final fileUrlProvider = FutureProvider.autoDispose.family<String?, String>((
  ref,
  fileId,
) async {
  if (!ref.watch(isAuthenticatedProvider)) return null;
  try {
    final signed = await ref.watch(fileUrlResolverProvider).resolve(fileId);
    return signed.url;
  } catch (error) {
    AppLogger.debug('File URL unresolved ($fileId): $error', name: 'files');
    return null;
  }
});
