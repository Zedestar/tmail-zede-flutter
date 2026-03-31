import 'package:flutter/material.dart';
import 'package:tmail_ui_user/features/base/mixin/message_dialog_action_manager.dart';
import 'package:tmail_ui_user/main/localizations/app_localizations.dart';
import 'package:tmail_ui_user/main/routes/route_navigation.dart';

typedef RuleRejectConfirmAction = void Function(dynamic ruleRequest);

mixin ValidateRuleRejectActionMixin {
  void showConfirmRejectDialog({
    required BuildContext context,
    required String message,
    required dynamic ruleRequest,
    required RuleRejectConfirmAction onConfirmAction,
  }) {
    final appLocalizations = AppLocalizations.of(context);

    MessageDialogActionManager().showConfirmDialogAction(
      context,
      title: appLocalizations.rejectConfirmDialogTitle,
      appLocalizations.rejectConfirmDialogSubtitle(message),
      appLocalizations.yes,
      alignCenter: true,
      cancelTitle: appLocalizations.cancel,
      onConfirmAction: () => onConfirmAction(ruleRequest),
      onCloseButtonAction: popBack,
    );
  }
}
