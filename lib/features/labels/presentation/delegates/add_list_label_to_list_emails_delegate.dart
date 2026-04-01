import 'package:core/presentation/resources/image_paths.dart';
import 'package:core/presentation/state/failure.dart';
import 'package:core/presentation/state/success.dart';
import 'package:flutter/material.dart';
import 'package:jmap_dart_client/jmap/mail/email/email.dart';
import 'package:labels/extensions/list_label_extension.dart';
import 'package:labels/model/label.dart';
import 'package:model/email/presentation_email.dart';
import 'package:model/extensions/list_presentation_email_extension.dart';
import 'package:tmail_ui_user/features/base/base_controller.dart';
import 'package:tmail_ui_user/features/email/domain/state/labels/add_list_label_to_list_email_state.dart';
import 'package:tmail_ui_user/features/email/domain/usecases/labels/add_list_label_to_list_emails_interactor.dart';
import 'package:tmail_ui_user/features/home/data/exceptions/session_exceptions.dart';
import 'package:tmail_ui_user/features/labels/domain/exceptions/label_exceptions.dart';
import 'package:jmap_dart_client/jmap/mail/email/keyword_identifier.dart';
import 'package:tmail_ui_user/features/labels/presentation/label_controller.dart';
import 'package:tmail_ui_user/features/labels/presentation/widgets/choose_label_modal.dart';
import 'package:tmail_ui_user/main/routes/dialog_router.dart';

typedef OnSyncListLabelForListEmail = void Function(
  List<EmailId> emailIds,
  List<KeyWordIdentifier> labelKeywords,
  {bool shouldRemove}
);

class AddListLabelToListEmailsDelegate extends BaseController {
  final LabelController _labelController;
  final AddListLabelToListEmailsInteractor _interactor;

  AddListLabelToListEmailsDelegate(this._labelController, this._interactor);

  OnSyncListLabelForListEmail? _pendingOnSync;

  Future<void> openChooseLabelModal({
    required List<PresentationEmail> selectedEmails,
    required ImagePaths imagePaths,
    required VoidCallback onCancel,
    required OnSyncListLabelForListEmail onSync,
  }) async {
    await DialogRouter().openDialogModal(
      child: ChooseLabelModal(
        labels: _labelController.labels,
        onLabelAsToEmailsAction: (labels) {
          onCancel();
          _addLabels(labels, selectedEmails.listEmailIds, onSync);
        },
        imagePaths: imagePaths,
      ),
      dialogLabel: 'choose-label-modal',
    );
  }

  void _addLabels(
    List<Label> labels,
    List<EmailId> emailIds,
    OnSyncListLabelForListEmail onSync,
  ) {
    final session = _labelController.session;
    final accountId = _labelController.accountId;
    final labelKeywords = labels.keywords;
    final labelDisplays = labels.displayNameNotNullList;

    if (session == null) {
      emitFailure(
        controller: this,
        failure: AddListLabelsToListEmailsFailure(
          exception: NotFoundSessionException(),
          labelDisplays: labelDisplays,
        ),
      );
      return;
    }

    if (accountId == null) {
      emitFailure(
        controller: this,
        failure: AddListLabelsToListEmailsFailure(
          exception: NotFoundAccountIdException(),
          labelDisplays: labelDisplays,
        ),
      );
      return;
    }

    if (labelKeywords.isEmpty) {
      emitFailure(
        controller: this,
        failure: AddListLabelsToListEmailsFailure(
          exception: const LabelKeywordIsNull(),
          labelDisplays: labelDisplays,
        ),
      );
      return;
    }

    // Store callback before consumeState (stream-based async)
    _pendingOnSync = onSync;
    consumeState(
      _interactor.execute(session, accountId, emailIds, labelKeywords, labelDisplays),
    );
  }

  @override
  void handleSuccessViewState(Success success) {
    if (success is AddListLabelsToListEmailsSuccess) {
      toastManager.showMessageSuccess(success);
      _pendingOnSync?.call(success.emailIds, success.labelKeywords, shouldRemove: false);
    } else if (success is AddListLabelsToListEmailsHasSomeFailure) {
      toastManager.showMessageSuccess(success);
      _pendingOnSync?.call(success.emailIds, success.labelKeywords, shouldRemove: false);
    }
  }

  @override
  void handleFailureViewState(Failure failure) {
    if (failure is AddListLabelsToListEmailsFailure) {
      toastManager.showMessageFailure(failure);
    }
  }

  @override
  void onClose() {
    _pendingOnSync = null;
    super.onClose();
  }
}
