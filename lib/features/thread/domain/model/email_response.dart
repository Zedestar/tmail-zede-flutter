
import 'package:equatable/equatable.dart';
import 'package:jmap_dart_client/jmap/core/state.dart';
import 'package:jmap_dart_client/jmap/mail/email/email.dart';
import 'package:jmap_dart_client/jmap/thread/thread.dart';
import 'package:tmail_ui_user/features/thread/data/model/email_change_response.dart';
import 'package:tmail_ui_user/features/thread/domain/extensions/list_thread_extension.dart';
import 'package:tmail_ui_user/features/thread/domain/model/thread_email.dart';

class EmailsResponse with EquatableMixin {
  final List<Email>? emailList;
  final List<EmailId>? notFoundEmailIds;
  final State? state;
  final EmailChangeResponse? emailChangeResponse;
  final List<Thread>? threadLists;

  const EmailsResponse({
    this.emailList,
    this.notFoundEmailIds,
    this.state,
    this.emailChangeResponse,
    this.threadLists,
  });

  bool hasEmails() => emailList != null && emailList!.isNotEmpty;

  bool hasState() => state != null;

  bool get existNotFoundEmails => notFoundEmailIds?.isNotEmpty == true;

  List<ThreadEmail> get threadEmails {
    final emails = emailList;
    if (emails == null || emails.isEmpty) return [];

    final threadMap = threadLists.toThreadEmailIdsMap();

    return emails.map((email) {
      return ThreadEmail.fromEmail(
        email,
        emailIdsInThread: threadMap[email.threadId],
      );
    }).toList();
  }

  @override
  List<Object?> get props => [
    emailList,
    notFoundEmailIds,
    state,
    emailChangeResponse,
    threadLists,
  ];

  EmailsResponse copyWith({
    List<Email>? emailList,
    List<EmailId>? notFoundEmailIds,
    State? state,
    EmailChangeResponse? emailChangeResponse,
    List<Thread>? threadLists
  }) {
    return EmailsResponse(
      emailList: emailList ?? this.emailList,
      notFoundEmailIds: notFoundEmailIds ?? this.notFoundEmailIds,
      state: state ?? this.state,
      emailChangeResponse: emailChangeResponse ?? this.emailChangeResponse,
      threadLists: threadLists ?? this.threadLists,
    );
  }
}