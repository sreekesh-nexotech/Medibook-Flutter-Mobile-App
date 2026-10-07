/// One hospital banner (§7.4). Banners belong to a hospital; there is no
/// platform-wide list, so Home stitches together the visible hospitals'
/// banners.
///
/// Named `HospitalBanner` so it never collides with Flutter's `Banner` widget.
class HospitalBanner {
  const HospitalBanner({
    required this.id,
    required this.title,
    required this.hospitalId,
    this.body,
    this.imageFileId,
    this.ctaLabel,
    this.ctaTarget,
    this.sortOrder = 0,
    this.startsAt,
    this.endsAt,
  });

  final String id;
  final String title;
  final String? body;

  /// A file id (§11.4) — resolve before rendering; null when the banner is
  /// text only.
  final String? imageFileId;
  final String? ctaLabel;

  /// A deep link such as `medibook://booking`, or null.
  final String? ctaTarget;
  final int sortOrder;
  final DateTime? startsAt;
  final DateTime? endsAt;

  /// The hospital this banner belongs to — set by the caller that fetched it,
  /// so Home can open the right facility.
  final String hospitalId;
}
