import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/doctor.dart';
import 'fee_breakdown_card.dart';
import 'file_image.dart';

/// Booking step 4's confirmation card, as the design draws it: the doctor
/// (`52` avatar, name `16/600`, "dept · hospital" `12` muted) over a
/// hairline; the summary rows (`14`: label muted, value primary `500`,
/// `12px 0`); then the price block — a hairline, the fee lines (`4px 0`), and
/// "Total payable" (`16/600`) against the total (`20/700`, brand).
///
/// The fee rows are the backend's quote lines; the total is the backend's
/// figure (§8.3).
class BookingSummaryCard extends StatelessWidget {
  const BookingSummaryCard({
    super.key,
    required this.doctor,
    required this.doctorSub,
    required this.rows,
    required this.feeRows,
    required this.totalPaise,
  });

  final DoctorCard doctor;

  /// "General · Periyar Medical Centre".
  final String doctorSub;

  /// Patient / Department / Date / Time, in order.
  final List<({String label, String value})> rows;

  final List<FeeRowData> feeRows;
  final int totalPaise;

  @override
  Widget build(BuildContext context) {
    final hairline = BorderSide(color: AppColors.borderSubtle, width: 1.h);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.only(bottom: 16.h),
            decoration: BoxDecoration(border: Border(bottom: hairline)),
            child: Row(
              children: [
                ClipOval(
                  child: SizedBox(
                    width: 52.w,
                    height: 52.w,
                    child: AppFileImage(
                      fileId: doctor.photoFileId,
                      fallback: ColoredBox(
                        color: AppColors.surfaceTint,
                        child: Center(
                          child: Text(
                            _initials(doctor.name),
                            style: AppText.poppins(
                              size: AppFontSize.base,
                              weight: AppText.semibold,
                              color: AppColors.brand,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        doctor.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.poppins(
                          size: AppFontSize.body,
                          weight: AppText.semibold,
                          color: AppColors.textStrong,
                        ),
                      ),
                      Text(
                        doctorSub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.poppins(
                          size: AppFontSize.xs,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          for (final row in rows)
            _Row(label: row.label, value: row.value, vertical: 12),
          Container(
            margin: EdgeInsets.only(top: 8.h),
            padding: EdgeInsets.only(top: 16.h),
            decoration: BoxDecoration(border: Border(top: hairline)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final fee in feeRows)
                  _Row(
                    label: fee.label,
                    value: fee.isDiscount
                        ? '− ${Money.inr(-fee.amountPaise)}'
                        : Money.inr(fee.amountPaise),
                    vertical: 4,
                  ),
                Container(
                  margin: EdgeInsets.only(top: 8.h),
                  padding: EdgeInsets.only(top: 12.h),
                  decoration: BoxDecoration(border: Border(top: hairline)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Text(
                          'Total payable',
                          style: AppText.poppins(
                            size: AppFontSize.body,
                            weight: AppText.semibold,
                            color: AppColors.textStrong,
                          ),
                        ),
                      ),
                      Text(
                        Money.inr(totalPaise),
                        style: AppText.poppins(
                          size: AppFontSize.h3,
                          weight: AppText.bold,
                          color: AppColors.brand,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _initials(String name) => name
      .replaceAll(RegExp(r'^Dr\.?\s+'), '')
      .split(' ')
      .where((w) => w.isNotEmpty)
      .take(2)
      .map((w) => w[0].toUpperCase())
      .join();
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    required this.vertical,
  });

  final String label;
  final String value;
  final double vertical;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: vertical.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppText.poppins(
              size: AppFontSize.base,
              color: AppColors.textMuted,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: AppText.poppins(
                size: AppFontSize.base,
                weight: AppText.medium,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
