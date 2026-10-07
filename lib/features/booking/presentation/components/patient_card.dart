import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/theme.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_tag.dart';
import '../../domain/entities/person_summary.dart';
import '../../domain/entities/hospital_clock.dart';

/// Booking step 3 patient row, as the design draws it: a `Card` with a `42`
/// avatar, the name (`14/600`, navy) over age · gender (`12`, muted), and the
/// relation [AppTag] on the right that turns active when selected. A `1.5px`
/// brand ring marks the chosen patient; unselected keeps a transparent ring
/// so nothing shifts.
class PatientCard extends StatelessWidget {
  const PatientCard({
    super.key,
    required this.person,
    required this.selected,
    this.onTap,
  });

  final PersonSummary person;
  final bool selected;
  final VoidCallback? onTap;

  /// "29 years · Female" from what the record carries; never invented.
  String get _meta {
    final parts = <String>[];
    final dob = HospitalClock.parseDate(person.dateOfBirth);
    if (dob != null) parts.add('${AppDates.ageInYears(dob)} years');
    final gender = person.gender;
    if (gender != null && gender.isNotEmpty && gender != 'undisclosed') {
      parts.add('${gender[0].toUpperCase()}${gender.substring(1)}');
    }
    return parts.isEmpty ? 'Details not added' : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final relation = person.isSelf ? 'You' : person.relationLabel;
    return Semantics(
      button: true,
      selected: selected,
      label: '${person.fullName}, $relation, $_meta',
      child: ExcludeSemantics(
        child: Container(
          padding: EdgeInsets.all(1.5.r),
          decoration: BoxDecoration(
            color: selected ? AppColors.brand : Colors.transparent,
            borderRadius: AppRadii.lg,
          ),
          child: AppCard(
            onTap: onTap,
            child: Row(
              children: [
                AppAvatar(name: person.fullName, size: 42),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        person.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.poppins(
                          size: AppFontSize.base,
                          weight: AppText.semibold,
                          color: AppColors.textStrong,
                        ),
                      ),
                      Text(
                        _meta,
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
                SizedBox(width: 12.w),
                AppTag(label: relation, active: selected),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
