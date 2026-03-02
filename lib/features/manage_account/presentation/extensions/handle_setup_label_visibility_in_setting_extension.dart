import 'package:get/get.dart';
import 'package:tmail_ui_user/features/manage_account/presentation/manage_account_dashboard_controller.dart';

extension HandleSetupLabelVisibilityInSettingExtension
    on ManageAccountDashBoardController {
  bool get isLabelCapabilitySupported {
    final accountId = this.accountId.value;
    final session = sessionCurrent;

    if (accountId == null || session == null) return false;

    return labelController.isLabelCapabilitySupported(session, accountId);
  }

  bool get isLabelAvailable {
    return labelController.isLabelSettingEnabled.isTrue &&
        isLabelCapabilitySupported;
  }

  void updateLabelSettingEnabled(bool isEnabled) {
    if (accountId.value == null) return;
    labelController.updateLabelSettingEnabled(isEnabled, accountId.value!);
  }
}
