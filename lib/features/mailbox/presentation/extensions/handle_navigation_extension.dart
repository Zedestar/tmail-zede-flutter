import 'package:tmail_ui_user/features/mailbox/presentation/extensions/handle_label_action_type_extension.dart';
import 'package:tmail_ui_user/features/mailbox/presentation/mailbox_controller.dart';
import 'package:tmail_ui_user/features/mailbox/presentation/model/presentation_label_mailbox.dart';
import 'package:tmail_ui_user/main/routes/app_routes.dart';
import 'package:tmail_ui_user/main/routes/route_navigation.dart';

extension HandleNavigationExtension on MailboxController {
  void handleLabelNavigation() {
    final router = navigationRouter;
    if (router == null) return;

    final labelId = router.labelId;
    if (labelId == null) return;

    final matchedLabel = mailboxDashBoardController.getLabelById(labelId);

    if (matchedLabel != null) {
      final labelMailbox = PresentationLabelMailbox.initial(matchedLabel);

      if (router.emailId != null) {
        openEmailInsideMailboxFromLocationBar(
          labelMailbox,
          router.emailId!,
        );
      } else {
        openMailboxFromLocationBar(labelMailbox);
      }

      mailboxDashBoardController.scrollToLabelListView();
    } else {
      clearNavigationRouter();
      popAndPush(AppRoutes.unknownRoutePage);
    }
  }
}
