import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/file_url_provider.dart';

/// A `*_file_id` rendered as an image (§11.4), with an honest fallback.
///
/// The id is resolved to a signed URL through [fileUrlProvider]; the bytes
/// are cached by `cached_network_image` under the **file id** (not the URL),
/// so a re-signed URL never re-downloads. A signed-out viewer, a null id or
/// an unresolvable id all render [fallback] — initials or a tinted block —
/// never a broken-image box.
class AppFileImage extends ConsumerWidget {
  const AppFileImage({
    super.key,
    required this.fileId,
    required this.fallback,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.width,
    this.height,
  });

  final String? fileId;
  final Widget fallback;
  final BoxFit fit;
  final Alignment alignment;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = fileId;
    if (id == null || id.isEmpty) return fallback;
    final url = ref.watch(fileUrlProvider(id));
    return url.maybeWhen(
      data: (resolved) {
        if (resolved == null) return fallback;
        return CachedNetworkImage(
          imageUrl: resolved,
          cacheKey: id,
          fit: fit,
          alignment: alignment,
          width: width,
          height: height,
          placeholder: (_, _) => fallback,
          errorWidget: (_, _, _) => fallback,
        );
      },
      orElse: () => fallback,
    );
  }
}
