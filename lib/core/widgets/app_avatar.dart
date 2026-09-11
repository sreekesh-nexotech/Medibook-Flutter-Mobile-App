import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../app/theme/colors.dart';
import '../../app/theme/typography.dart';

/// A circular avatar. Renders [imageAsset] (local seed photos) or [imageUrl]
/// (future API, via `CachedNetworkImage`); falls back to brand-colored initials
/// on a tint circle. [ring] wraps it in the design's stacked
/// `2px surface + 3.5px brand` ring.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.name,
    this.imageAsset,
    this.imageUrl,
    this.size = 44,
    this.ring = false,
  });

  final String name;

  /// Local asset path (seed doctors / user).
  final String? imageAsset;

  /// Optional network image (future API).
  final String? imageUrl;
  final double size;
  final bool ring;

  String get _initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '';
    final first = parts[0].substring(0, 1);
    final second = parts.length > 1 ? parts[1].substring(0, 1) : '';
    return (first + second).toUpperCase();
  }

  Widget _fallback() {
    return Center(
      child: Text(
        _initials,
        style: AppText.poppins(
          size: size * 0.38,
          weight: AppText.semibold,
          color: AppColors.brand,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget inner;
    if (imageUrl != null) {
      inner = CachedNetworkImage(
        imageUrl: imageUrl!,
        fit: BoxFit.cover,
        width: size.w,
        height: size.w,
        placeholder: (_, _) => _fallback(),
        errorWidget: (_, _, _) => _fallback(),
      );
    } else if (imageAsset != null) {
      inner = Image.asset(
        imageAsset!,
        fit: BoxFit.cover,
        width: size.w,
        height: size.w,
        errorBuilder: (_, _, _) => _fallback(),
      );
    } else {
      inner = _fallback();
    }

    final circle = Container(
      width: size.w,
      height: size.w,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: AppColors.surfaceTint,
        shape: BoxShape.circle,
      ),
      child: inner,
    );

    if (!ring) return circle;

    // Stacked ring: 2px surface gap, then a 1.5px brand band (→ 3.5px total),
    // matching `0 0 0 2px surface, 0 0 0 3.5px brand`.
    return Container(
      padding: EdgeInsets.all(1.5.w),
      decoration: const BoxDecoration(
        color: AppColors.brand,
        shape: BoxShape.circle,
      ),
      child: Container(
        padding: EdgeInsets.all(2.w),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
        ),
        child: circle,
      ),
    );
  }
}
