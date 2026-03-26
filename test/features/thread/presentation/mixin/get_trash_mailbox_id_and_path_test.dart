import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:jmap_dart_client/jmap/core/id.dart';
import 'package:jmap_dart_client/jmap/mail/mailbox/mailbox.dart';
import 'package:jmap_dart_client/jmap/mail/mailbox/namespace.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:model/mailbox/presentation_mailbox.dart';
import 'package:tmail_ui_user/features/mailbox_dashboard/presentation/controller/mailbox_dashboard_controller.dart';
import 'package:tmail_ui_user/features/mailbox_dashboard/presentation/extensions/get_trash_mailbox_id_and_path_extension.dart';

import 'get_trash_mailbox_id_and_path_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<MailboxDashBoardController>(),
])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final defaultTrashId = MailboxId(Id('default-trash'));
  final teamNamespace = Namespace('#TeamMailbox');
  final teamMailboxId = MailboxId(Id('team-root'));
  final teamTrashId = MailboxId(Id('team-trash'));

  final personalMailbox = PresentationMailbox(
    MailboxId(Id('personal-inbox')),
    name: MailboxName('Inbox'),
  );

  final teamMailbox = PresentationMailbox(
    teamMailboxId,
    name: MailboxName('Team'),
    namespace: teamNamespace,
  );

  final teamMailboxWithNullNamespace = PresentationMailbox(
    MailboxId(Id('team-no-ns')),
    name: MailboxName('Team No NS'),
  );

  late MockMailboxDashBoardController mockDashBoardController;

  setUp(() {
    Get.testMode = true;

    mockDashBoardController = MockMailboxDashBoardController();

    when(mockDashBoardController.mapDefaultMailboxIdByRole)
        .thenReturn({PresentationMailbox.roleTrash: defaultTrashId});
    when(mockDashBoardController.selectedMailbox)
        .thenReturn(Rxn<PresentationMailbox>());
  });

  group('GetTrashMailboxIdAndPathExtension::getTrashMailboxIdAndPath', () {
    test(
      'SHOULD return default trash id with null path '
      'WHEN emailMailbox is personal (no namespace)',
      () {
        final result = mockDashBoardController.getTrashMailboxIdAndPath(
          personalMailbox,
        );

        expect(result.trashId, equals(defaultTrashId));
        expect(result.trashPath, isNull);
      },
    );

    test(
      'SHOULD return default trash id with null path '
      'WHEN selectedMailbox is personal',
      () {
        when(mockDashBoardController.selectedMailbox)
            .thenReturn(Rxn(personalMailbox));

        final result = mockDashBoardController.getTrashMailboxIdAndPath(
          teamMailbox,
        );

        expect(result.trashId, equals(defaultTrashId));
        expect(result.trashPath, isNull);
      },
    );

    test(
      'SHOULD use selectedMailbox over emailMailbox '
      'WHEN selectedMailbox is not null',
      () {
        when(mockDashBoardController.selectedMailbox)
            .thenReturn(Rxn(personalMailbox));

        final result = mockDashBoardController.getTrashMailboxIdAndPath(
          teamMailbox,
        );

        expect(result.trashId, equals(defaultTrashId));
        expect(result.trashPath, isNull);
      },
    );

    test(
      'SHOULD return default trash id with null path '
      'WHEN mailbox namespace is null',
      () {
        final result = mockDashBoardController.getTrashMailboxIdAndPath(
          teamMailboxWithNullNamespace,
        );

        expect(result.trashId, equals(defaultTrashId));
        expect(result.trashPath, isNull);
      },
    );

    test(
      'SHOULD return default trash id with null path '
      'WHEN findDefaultMailboxIdInTeamMailbox returns null',
      () {
        when(mockDashBoardController.findDefaultMailboxIdInTeamMailbox(
          namespace: teamNamespace,
          mailboxName: PresentationMailbox.trashRole,
        )).thenReturn(null);

        final result = mockDashBoardController.getTrashMailboxIdAndPath(
          teamMailbox,
        );

        expect(result.trashId, equals(defaultTrashId));
        expect(result.trashPath, isNull);
      },
    );

    test(
      'SHOULD return team trash id with path '
      'WHEN team mailbox has trash folder',
      () {
        when(mockDashBoardController.findDefaultMailboxIdInTeamMailbox(
          namespace: teamNamespace,
          mailboxName: PresentationMailbox.trashRole,
        )).thenReturn(teamTrashId);
        when(mockDashBoardController.getTeamMailboxNodePathWithSeparator(
          mailboxId: teamTrashId,
        )).thenReturn('Team/Trash');

        final result = mockDashBoardController.getTrashMailboxIdAndPath(
          teamMailbox,
        );

        expect(result.trashId, equals(teamTrashId));
        expect(result.trashPath, equals('Team/Trash'));
      },
    );

    test(
      'SHOULD return team trash id with null path '
      'WHEN getTeamMailboxNodePathWithSeparator returns null',
      () {
        when(mockDashBoardController.findDefaultMailboxIdInTeamMailbox(
          namespace: teamNamespace,
          mailboxName: PresentationMailbox.trashRole,
        )).thenReturn(teamTrashId);
        when(mockDashBoardController.getTeamMailboxNodePathWithSeparator(
          mailboxId: teamTrashId,
        )).thenReturn(null);

        final result = mockDashBoardController.getTrashMailboxIdAndPath(
          teamMailbox,
        );

        expect(result.trashId, equals(teamTrashId));
        expect(result.trashPath, isNull);
      },
    );

    test(
      'SHOULD return null trash id with null path '
      'WHEN mapDefaultMailboxIdByRole has no trash entry '
      'AND mailbox is personal',
      () {
        when(mockDashBoardController.mapDefaultMailboxIdByRole).thenReturn({});

        final result = mockDashBoardController.getTrashMailboxIdAndPath(
          personalMailbox,
        );

        expect(result.trashId, isNull);
        expect(result.trashPath, isNull);
      },
    );
  });
}
