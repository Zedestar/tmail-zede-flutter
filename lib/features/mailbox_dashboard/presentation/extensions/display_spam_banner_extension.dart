import 'package:flutter/material.dart' ;
import 'package:get/get.dart';
import 'package:model/email/read_actions.dart';
import 'package:model/extensions/presentation_mailbox_extension.dart';
import 'package:model/mailbox/presentation_mailbox.dart';
import 'package:tmail_ui_user/features/base/widget/report_message_banner.dart';
import 'package:tmail_ui_user/features/email/domain/state/mark_as_email_read_state.dart';
import 'package:tmail_ui_user/features/home/data/exceptions/session_exceptions.dart';
import 'package:tmail_ui_user/features/mailbox/presentation/extensions/presentation_mailbox_extension.dart';
import 'package:tmail_ui_user/features/mailbox_dashboard/domain/exceptions/spam_report_exception.dart';
import 'package:tmail_ui_user/features/mailbox_dashboard/presentation/controller/mailbox_dashboard_controller.dart';
import 'package:tmail_ui_user/features/thread/presentation/styles/spam_banner/spam_report_banner_web_styles.dart';
import 'package:tmail_ui_user/main/localizations/app_localizations.dart';

extension DisplaySpamBannerExtension on MailboxDashBoardController {
  Widget buildSpamBanner({
    required AppLocalizations appLocalizations,
    required bool isDesktop,
  }) {
    return Obx(() {
      if (spamReportController.isSpamBannerVisible.isFalse) {
        return const SizedBox.shrink();
      }

      return _buildBannerContent(appLocalizations, isDesktop);
    });
  }

  Widget _buildBannerContent(
    AppLocalizations appLocalizations,
    bool isDesktop,
  ) {
    return ReportMessageBanner(
      imagePaths: imagePaths,
      message: appLocalizations.countMessageInSpam(
        spamReportController.numberOfUnreadSpamEmails,
      ),
      positiveName: appLocalizations.view,
      isDesktop: isDesktop,
      margin: SpamReportBannerWebStyles.bannerMargin,
      onPositiveAction: _openSpamMailbox,
      onNegativeAction: () => _dismissSpamBanner(appLocalizations),
    );
  }

  void _openSpamMailbox() {
    PresentationMailbox? spamMailbox =
        spamReportController.presentationSpamMailbox.value;

    spamReportController.setSpamPresentationMailbox(null);

    if (spamMailbox == null && spamMailboxId != null) {
      spamMailbox = mapMailboxById[spamMailboxId];
    }

    if (spamMailbox != null) {
      openMailboxAction(spamMailbox);
    }
  }

  void _dismissSpamBanner(AppLocalizations appLocalizations) {
    final spamMailbox = spamReportController.presentationSpamMailbox.value;

    spamReportController.setSpamPresentationMailbox(null);

    if (spamMailbox == null) {
      emitFailure(
        controller: this,
        failure: MarkAsEmailReadFailure(
          ReadActions.markAsRead,
          exception: NotFoundSpamMailboxException(),
        ),
      );
      return;
    }


    final session = sessionCurrent;
    if (session == null) {
      emitFailure(
        controller: this,
        failure: MarkAsEmailReadFailure(
          ReadActions.markAsRead,
          exception: NotFoundSessionException(),
        ),
      );
      return;
    }

    final currentAccountId = accountId.value;
    if (currentAccountId == null) {
      emitFailure(
        controller: this,
        failure: MarkAsEmailReadFailure(
          ReadActions.markAsRead,
          exception: NotFoundAccountIdException(),
        ),
      );
      return;
    }

    markAsReadMailbox(
      session,
      currentAccountId,
      spamMailbox.id,
      spamMailbox.getDisplayNameWithoutContext(appLocalizations),
      spamMailbox.countUnreadEmails,
    );
  }
}
