import 'package:core/presentation/state/failure.dart';
import 'package:core/presentation/state/success.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:jmap_dart_client/jmap/account_id.dart';
import 'package:jmap_dart_client/jmap/core/user_name.dart';
import 'package:model/extensions/mailbox_extension.dart';
import 'package:model/extensions/presentation_mailbox_extension.dart';
import 'package:model/mailbox/presentation_mailbox.dart';
import 'package:tmail_ui_user/features/base/base_controller.dart';
import 'package:tmail_ui_user/features/mailbox_dashboard/domain/model/spam_report_state.dart';
import 'package:tmail_ui_user/features/mailbox_dashboard/domain/state/get_spam_mailbox_cached_state.dart';
import 'package:tmail_ui_user/features/mailbox_dashboard/domain/state/get_spam_report_state.dart';
import 'package:tmail_ui_user/features/mailbox_dashboard/domain/usecases/get_spam_mailbox_cached_interactor.dart';
import 'package:tmail_ui_user/features/mailbox_dashboard/domain/usecases/get_spam_report_state_interactor.dart';
import 'package:tmail_ui_user/features/mailbox_dashboard/domain/usecases/store_last_time_dismissed_spam_reported_interactor.dart';
import 'package:tmail_ui_user/features/mailbox_dashboard/domain/usecases/store_spam_report_state_interactor.dart';
import 'package:tmail_ui_user/features/mailbox_dashboard/presentation/controller/mailbox_dashboard_controller.dart';
import 'package:tmail_ui_user/features/mailbox_dashboard/presentation/model/loader_status.dart';
import 'package:tmail_ui_user/main/routes/route_navigation.dart';

class SpamReportController extends BaseController {
  final StoreLastTimeDismissedSpamReportedInteractor _storeLastTimeDismissedSpamReportedInteractor;
  final StoreSpamReportStateInteractor _storeSpamReportStateInteractor;
  final GetSpamReportStateInteractor _getSpamReportStateInteractor;
  final GetSpamMailboxCachedInteractor _getSpamMailboxCachedInteractor;

  final presentationSpamMailbox = Rxn<PresentationMailbox>();
  final isSpamBannerVisible = RxBool(false);

  AppLifecycleListener? _appLifecycleListener;
  LoaderStatus _spamReportLoaderStatus = LoaderStatus.idle;
  SpamReportState spamReportState = SpamReportState.enabled;

  SpamReportController(
    this._storeLastTimeDismissedSpamReportedInteractor,
    this._storeSpamReportStateInteractor,
    this._getSpamReportStateInteractor,
    this._getSpamMailboxCachedInteractor
  );

  @override
  void onInit() {
    super.onInit();
    _appLifecycleListener ??= AppLifecycleListener(
      onResume: () {
        if (_spamReportLoaderStatus == LoaderStatus.loading) {
          return;
        }
        getSpamReportStateAction();
      },
    );
  }

  @override
  void handleSuccessViewState(Success success) {
    if (success is GetSpamReportStateLoading) {
      _spamReportLoaderStatus = LoaderStatus.loading;
    } else if (success is GetSpamReportStateSuccess) {
      _loadSpamReportConfigSuccess(success.spamReportState);
    } else if (success is GetSpamMailboxCachedSuccess) {
      _handleGetSpamCachedSuccess(success.spamMailbox.toPresentationMailbox());
    } else {
      super.handleSuccessViewState(success);
    }
  }

  @override
  void handleFailureViewState(Failure failure) {
    if (failure is GetSpamMailboxCachedFailure) {
      setSpamPresentationMailbox(null);
    } else if (failure is GetSpamReportStateFailure) {
      _spamReportLoaderStatus = LoaderStatus.completed;
    } else {
      super.handleFailureViewState(failure);
    }
  }

  @override
  void handleErrorViewState(Object error, StackTrace stackTrace) {
    super.handleErrorViewState(error, stackTrace);
    _spamReportLoaderStatus = LoaderStatus.completed;
  }

  void _loadSpamReportConfigSuccess(SpamReportState newState) {
    setSpamReportState(newState);
    _spamReportLoaderStatus = LoaderStatus.completed;
    updateSpamBannerVisibility();
  }

  void getSpamMailboxCached(AccountId accountId, UserName userName) {
    consumeState(_getSpamMailboxCachedInteractor.execute(accountId, userName));
  }

  void _storeLastTimeDismissedSpamReportedAction() {
    consumeState(
      _storeLastTimeDismissedSpamReportedInteractor.execute(DateTime.now()),
    );
  }

  String get numberOfUnreadSpamEmails => presentationSpamMailbox.value?.countUnReadEmailsAsString ?? '';

  bool get enableSpamReport => spamReportState == SpamReportState.enabled;

  void setSpamReportState(SpamReportState newState) {
    spamReportState = newState;
  }

  void storeSpamReportStateAction(SpamReportState newState) {
    setSpamReportState(newState);
    consumeState(_storeSpamReportStateInteractor.execute(newState));

    if (isSpamBannerVisible.isTrue && newState == SpamReportState.disabled) {
      setSpamPresentationMailbox(null);
      _setSpamBannerVisibility(false);
    } else if (isSpamBannerVisible.isFalse &&
        newState == SpamReportState.enabled) {
      getBinding<MailboxDashBoardController>()?.refreshSpamReportBanner();
    }
  }

  void getSpamReportStateAction() {
    consumeState(_getSpamReportStateInteractor.execute());
  }

  void setSpamPresentationMailbox(PresentationMailbox? spamMailbox) {
    presentationSpamMailbox.value = spamMailbox;
    updateSpamBannerVisibility();
  }

  void _setSpamBannerVisibility(bool isVisible) {
    isSpamBannerVisible.value = isVisible;
  }

  void updateSpamBannerVisibility() {
    final dashboardController = getBinding<MailboxDashBoardController>();
    if (dashboardController == null) {
      _setSpamBannerVisibility(false);
      return;
    }

    final isSpamMailboxOpened =
        dashboardController.selectedMailbox.value?.isSpam == true;
    final isSpamDataAvailable = presentationSpamMailbox.value != null;
    final isEmailOpened = dashboardController.isEmailOpened;

    final isSpamBannerVisible = enableSpamReport &&
        isSpamDataAvailable &&
        !isSpamMailboxOpened &&
        !isEmailOpened;

    _setSpamBannerVisibility(isSpamBannerVisible);
  }

  void _handleGetSpamCachedSuccess(PresentationMailbox spamMailbox) {
    setSpamPresentationMailbox(spamMailbox);

    if (isSpamBannerVisible.isTrue) {
      _storeLastTimeDismissedSpamReportedAction();
    }
  }

  @override
  void onClose() {
    _appLifecycleListener?.dispose();
    super.onClose();
  }
}
