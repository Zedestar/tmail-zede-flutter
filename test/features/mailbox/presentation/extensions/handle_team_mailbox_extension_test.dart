import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:jmap_dart_client/jmap/core/id.dart';
import 'package:jmap_dart_client/jmap/mail/mailbox/mailbox.dart';
import 'package:jmap_dart_client/jmap/mail/mailbox/namespace.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:model/mailbox/presentation_mailbox.dart';
import 'package:tmail_ui_user/features/mailbox/presentation/mailbox_controller.dart';
import 'package:tmail_ui_user/features/mailbox/presentation/mixin/handle_team_mailbox_mixin.dart';
import 'package:tmail_ui_user/features/mailbox/presentation/model/mailbox_node.dart';
import 'package:tmail_ui_user/features/mailbox/presentation/model/mailbox_tree.dart';

import 'handle_team_mailbox_extension_test.mocks.dart';

class TestHandleTeamMailboxMixin with HandleTeamMailboxMixin {}

@GenerateNiceMocks([
  MockSpec<MailboxController>(),
])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestHandleTeamMailboxMixin testMixin;
  late MockMailboxController mockMailboxController;

  final teamNamespace = Namespace('#TeamMailbox');
  final teamMailboxId = MailboxId(Id('team-root'));
  final teamTrashId = MailboxId(Id('team-trash'));
  final teamInboxId = MailboxId(Id('team-inbox'));
  final teamSentId = MailboxId(Id('team-sent'));

  MailboxTree buildTeamMailboxTree({
    List<MailboxNode>? teamChildren,
  }) {
    return MailboxTree(
      MailboxNode(
        MailboxNode.rootItem(),
        childrenItems: [
          MailboxNode(
            PresentationMailbox(
              teamMailboxId,
              name: MailboxName('Team'),
              namespace: teamNamespace,
            ),
            childrenItems: teamChildren ??
                [
                  MailboxNode(
                    PresentationMailbox(
                      teamTrashId,
                      name: MailboxName('Trash'),
                      namespace: teamNamespace,
                      parentId: teamMailboxId,
                    ),
                  ),
                  MailboxNode(
                    PresentationMailbox(
                      teamInboxId,
                      name: MailboxName('Inbox'),
                      namespace: teamNamespace,
                      parentId: teamMailboxId,
                    ),
                  ),
                  MailboxNode(
                    PresentationMailbox(
                      teamSentId,
                      name: MailboxName('Sent'),
                      namespace: teamNamespace,
                      parentId: teamMailboxId,
                    ),
                  ),
                ],
          ),
        ],
      ),
    );
  }

  setUp(() {
    Get.testMode = true;

    mockMailboxController = MockMailboxController();
    when(mockMailboxController.onStart)
        .thenReturn(InternalFinalCallback(callback: () {}));
    when(mockMailboxController.onDelete)
        .thenReturn(InternalFinalCallback(callback: () {}));

    Get.put<MailboxController>(mockMailboxController);

    testMixin = TestHandleTeamMailboxMixin();
  });

  tearDown(() {
    Get.reset();
  });

  group('HandleTeamMailboxMixin::findDefaultMailboxIdInTeamMailbox', () {
    test(
      'SHOULD return trash mailbox id '
      'WHEN namespace matches and trash mailbox exists',
      () {
        when(mockMailboxController.teamMailboxesTree)
            .thenReturn(buildTeamMailboxTree().obs);

        final result = testMixin.findDefaultMailboxIdInTeamMailbox(
          namespace: teamNamespace,
          mailboxName: PresentationMailbox.trashRole,
        );

        expect(result, equals(teamTrashId));
      },
    );

    test(
      'SHOULD return null '
      'WHEN namespace does not match any team mailbox',
      () {
        when(mockMailboxController.teamMailboxesTree)
            .thenReturn(buildTeamMailboxTree().obs);

        final result = testMixin.findDefaultMailboxIdInTeamMailbox(
          namespace: Namespace('#UnknownTeam'),
          mailboxName: PresentationMailbox.trashRole,
        );

        expect(result, isNull);
      },
    );

    test(
      'SHOULD return null '
      'WHEN mailbox name does not match any child',
      () {
        when(mockMailboxController.teamMailboxesTree)
            .thenReturn(buildTeamMailboxTree().obs);

        final result = testMixin.findDefaultMailboxIdInTeamMailbox(
          namespace: teamNamespace,
          mailboxName: 'archive',
        );

        expect(result, isNull);
      },
    );

    test(
      'SHOULD match mailbox name case-insensitively',
      () {
        when(mockMailboxController.teamMailboxesTree)
            .thenReturn(buildTeamMailboxTree().obs);

        final result = testMixin.findDefaultMailboxIdInTeamMailbox(
          namespace: teamNamespace,
          mailboxName: 'TRASH',
        );

        expect(result, equals(teamTrashId));
      },
    );

    test(
      'SHOULD return null '
      'WHEN team mailbox tree is empty',
      () {
        when(mockMailboxController.teamMailboxesTree)
            .thenReturn(MailboxTree(MailboxNode.root()).obs);

        final result = testMixin.findDefaultMailboxIdInTeamMailbox(
          namespace: teamNamespace,
          mailboxName: PresentationMailbox.trashRole,
        );

        expect(result, isNull);
      },
    );

    test(
      'SHOULD return null '
      'WHEN team mailbox has no children',
      () {
        when(mockMailboxController.teamMailboxesTree)
            .thenReturn(buildTeamMailboxTree(teamChildren: []).obs);

        final result = testMixin.findDefaultMailboxIdInTeamMailbox(
          namespace: teamNamespace,
          mailboxName: PresentationMailbox.trashRole,
        );

        expect(result, isNull);
      },
    );

    test(
      'SHOULD return correct mailbox id '
      'WHEN searching for inbox in team mailbox',
      () {
        when(mockMailboxController.teamMailboxesTree)
            .thenReturn(buildTeamMailboxTree().obs);

        final result = testMixin.findDefaultMailboxIdInTeamMailbox(
          namespace: teamNamespace,
          mailboxName: PresentationMailbox.inboxRole,
        );

        expect(result, equals(teamInboxId));
      },
    );

    test(
      'SHOULD return null '
      'WHEN MailboxController is not registered',
      () {
        Get.delete<MailboxController>();

        final result = testMixin.findDefaultMailboxIdInTeamMailbox(
          namespace: teamNamespace,
          mailboxName: PresentationMailbox.trashRole,
        );

        expect(result, isNull);
      },
    );
  });

  group('HandleTeamMailboxMixin::getTeamMailboxNodePathWithSeparator', () {
    test(
      'SHOULD return path with parent separator '
      'WHEN mailbox has a parent',
      () {
        when(mockMailboxController.teamMailboxesTree)
            .thenReturn(buildTeamMailboxTree().obs);

        final result = testMixin.getTeamMailboxNodePathWithSeparator(
          mailboxId: teamTrashId,
        );

        expect(result, equals('Team/Trash'));
      },
    );

    test(
      'SHOULD return path with custom separator '
      'WHEN custom pathSeparator is provided',
      () {
        when(mockMailboxController.teamMailboxesTree)
            .thenReturn(buildTeamMailboxTree().obs);

        final result = testMixin.getTeamMailboxNodePathWithSeparator(
          mailboxId: teamTrashId,
          pathSeparator: '.',
        );

        expect(result, equals('Team.Trash'));
      },
    );

    test(
      'SHOULD return null '
      'WHEN mailbox id does not exist in tree',
      () {
        when(mockMailboxController.teamMailboxesTree)
            .thenReturn(buildTeamMailboxTree().obs);

        final result = testMixin.getTeamMailboxNodePathWithSeparator(
          mailboxId: MailboxId(Id('non-existent')),
        );

        expect(result, isNull);
      },
    );

    test(
      'SHOULD return mailbox name only '
      'WHEN mailbox has no parent',
      () {
        when(mockMailboxController.teamMailboxesTree)
            .thenReturn(buildTeamMailboxTree().obs);

        final result = testMixin.getTeamMailboxNodePathWithSeparator(
          mailboxId: teamMailboxId,
        );

        expect(result, equals('Team'));
      },
    );

    test(
      'SHOULD return null '
      'WHEN MailboxController is not registered',
      () {
        Get.delete<MailboxController>();

        final result = testMixin.getTeamMailboxNodePathWithSeparator(
          mailboxId: teamTrashId,
        );

        expect(result, isNull);
      },
    );
  });
}
