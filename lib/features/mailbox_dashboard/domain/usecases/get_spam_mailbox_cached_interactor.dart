
import 'package:core/presentation/state/failure.dart';
import 'package:core/presentation/state/success.dart';
import 'package:dartz/dartz.dart';
import 'package:jmap_dart_client/jmap/account_id.dart';
import 'package:jmap_dart_client/jmap/core/user_name.dart';
import 'package:tmail_ui_user/features/mailbox_dashboard/domain/exceptions/spam_report_exception.dart';
import 'package:tmail_ui_user/features/mailbox_dashboard/domain/repository/spam_report_repository.dart';
import 'package:tmail_ui_user/features/mailbox_dashboard/domain/state/get_spam_mailbox_cached_state.dart';

class GetSpamMailboxCachedInteractor {
  static const int spamReportBannerDisplayIntervalInHour = 24;

  final SpamReportRepository _spamReportRepository;

  GetSpamMailboxCachedInteractor(this._spamReportRepository);

   Stream<Either<Failure, Success>> execute(AccountId accountId, UserName userName) async* {
    try {
      yield Right<Failure, Success>(GetSpamMailboxCachedLoading());
      if (await _validateIntervalToShowBanner()) {
        final spamMailbox = await _spamReportRepository.getSpamMailboxCached(
          accountId,
          userName,
        );
        final countUnreadSpamMailbox = spamMailbox.unreadEmails?.value.value.toInt() ?? 0;
        if (countUnreadSpamMailbox > 0) {
          yield Right<Failure, Success>(GetSpamMailboxCachedSuccess(spamMailbox));
        } else {
          yield Left<Failure, Success>(
            GetSpamMailboxCachedFailure(NoUnreadSpamEmailsException()),
          );
        }
      } else {
        yield Left<Failure, Success>(
          GetSpamMailboxCachedFailure(InvalidSpamDismissTimestampException()),
        );
      }
    } catch (e) {
      yield Left<Failure, Success>(GetSpamMailboxCachedFailure(e));
    }
  }

  Future<bool> _validateIntervalToShowBanner() async {
    final millisecondTimeDismiss =
        await _spamReportRepository.getLastTimeDismissedSpamReported();
    if (millisecondTimeDismiss > 0) {
      final timeDismissed =
          DateTime.fromMillisecondsSinceEpoch(millisecondTimeDismiss);
      final currentTime = DateTime.now();
      final durationTime = currentTime.difference(timeDismissed);
      final inHours = durationTime.inHours;
      return inHours > spamReportBannerDisplayIntervalInHour;
    } else {
      return true;
    }
  }
}