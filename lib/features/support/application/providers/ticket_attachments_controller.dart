import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/attachments/application/providers/attachments_provider.dart';
import '../../../common/attachments/application/states/attachment_upload_state.dart';
import '../../../common/attachments/domain/entities/stored_file.dart';

/// Up to five files on a support request or reply (§13,
/// `attachment_file_ids` ≤ 5, purpose `ticket_attachment`).
const int maxTicketAttachments = 5;

/// The form keys: the new-request form, and one reply box per ticket.
const String newTicketForm = 'new-ticket';
String ticketReplyForm(String ticketId) => 'reply:$ticketId';

/// Slot [index] of [form].
AttachmentSlot ticketAttachmentSlot(String form, int index) =>
    (purpose: FileUploadPurpose.ticketAttachment, form: form, index: index);

/// How many file slots [form] shows. Grows with "Attach a file", never past
/// [maxTicketAttachments]; back to 0 once the files are sent.
final ticketAttachmentCountProvider = StateProvider.autoDispose
    .family<int, String>((ref, form) => 0);

/// What a form's files add up to, for its Send button.
class TicketAttachments {
  const TicketAttachments({
    required this.readyFileIds,
    required this.isBusy,
    required this.hasProblem,
  });

  /// Files the scanner has passed — the only ones that can be sent.
  final List<String> readyFileIds;

  /// A file is still uploading or being checked: Send waits for it.
  final bool isBusy;

  /// A file failed, was rejected, or is stuck in the scan: it must be
  /// removed or replaced first, so nothing is silently left out.
  final bool hasProblem;
}

final ticketAttachmentsProvider = Provider.autoDispose
    .family<TicketAttachments, String>((ref, form) {
      final count = ref.watch(ticketAttachmentCountProvider(form));
      final ids = <String>[];
      var busy = false;
      var problem = false;
      for (var i = 0; i < count; i++) {
        final slot = ref.watch(
          attachmentSlotProvider(ticketAttachmentSlot(form, i)),
        );
        final id = slot.readyFileId;
        if (id != null) {
          ids.add(id);
        } else if (slot.isBusy) {
          busy = true;
        } else if (slot.status != AttachmentStatus.idle) {
          problem = true;
        }
      }
      return TicketAttachments(
        readyFileIds: ids,
        isBusy: busy,
        hasProblem: problem,
      );
    });

/// The files were sent with the request or reply: they now belong to it, so
/// the slots let go of them without deleting, and the form starts empty.
void handOverTicketAttachments(WidgetRef ref, String form) {
  final count = ref.read(ticketAttachmentCountProvider(form));
  for (var i = 0; i < count; i++) {
    ref
        .read(attachmentSlotProvider(ticketAttachmentSlot(form, i)).notifier)
        .detachOwnership();
  }
  ref.read(ticketAttachmentCountProvider(form).notifier).update((_) => 0);
}
