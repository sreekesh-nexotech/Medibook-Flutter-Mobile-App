import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/config/constants.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../common/attachments/domain/entities/stored_file.dart';
import '../../../common/attachments/presentation/components/attachment_upload_tile.dart';
import '../../application/providers/ticket_attachments_controller.dart';

/// "Attach a file" for a support request or reply (BL-SUP-006): up to five
/// PDFs or photos, each uploaded and virus-checked in its own tile before it
/// can be sent.
class TicketAttachmentsField extends ConsumerWidget {
  const TicketAttachmentsField({
    super.key,
    required this.form,
    this.enabled = true,
  });

  /// [newTicketForm] or [ticketReplyForm].
  final String form;

  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(ticketAttachmentCountProvider(form));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < count; i++) ...[
          AttachmentUploadTile(
            purpose: FileUploadPurpose.ticketAttachment,
            slot: ticketAttachmentSlot(form, i),
            title: count == 1 ? 'Attachment' : 'Attachment ${i + 1}',
            helper: 'A PDF or a photo (JPEG or PNG)',
            enabled: enabled,
          ),
          SizedBox(height: AppSpacing.x3.h),
        ],
        if (count < maxTicketAttachments)
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton(
              label: count == 0 ? 'Attach a file' : 'Attach another file',
              variant: AppButtonVariant.ghost,
              size: AppButtonSize.sm,
              leadingIcon: PhIcon.plus,
              disabled: !enabled,
              semanticLabel: count == 0
                  ? 'Attach a file — a PDF or a photo, up to '
                        '$maxTicketAttachments'
                  : 'Attach another file — ${maxTicketAttachments - count} '
                        'more allowed',
              onPressed: () =>
                  ref.read(ticketAttachmentCountProvider(form).notifier).state =
                      count + 1,
            ),
          ),
      ],
    );
  }
}
