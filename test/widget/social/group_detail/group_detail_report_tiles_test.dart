// test/widget/social/group_detail/group_detail_report_tiles_test.dart
//
// BUT-511 (Apple 1.2 / Play UGC): widget tests proving the Report tile is
// reachable from both group-detail surfaces (overflow menu + member action
// menu) and that tapping it opens [ReportContentDialog].
//
// Strategy: stub `PermissionService` via the production [ServiceLocator] so
// `GroupDetailAppBar._buildPopupMenu` and `GroupMemberCard.build` see a
// non-owner current user. We don't stub [ReportService] — verifying the
// reason-selection dialog appears (`reportDialogTitle`) is sufficient proof
// that the Report path was wired correctly.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/views/social/group_detail/group_detail_app_bar.dart';
import 'package:butlery/views/social/group_detail/group_member_card.dart';

/// Minimal `PermissionService` stub. Overrides only the surface
/// `_buildPopupMenu` and `GroupMemberCard.build` actually read. Treats the
/// current user as a regular member (not admin, no invite rights) — the
/// test cases that need admin would set `adminGroups` explicitly.
class _StubPermissionService extends Fake implements PermissionService {
  _StubPermissionService({required this.uid});

  final String uid;

  @override
  String? get currentUserId => uid;

  @override
  bool isGroupAdmin(String groupId) => false;

  @override
  bool canInviteToGroup(String groupId) => false;

  @override
  bool isOwner(String ownerId) => ownerId == uid;
}

FriendCategory _group({
  String id = 'g1',
  String ownerId = 'owner-uid',
  List<String> friendUserIds = const ['owner-uid', 'me-uid', 'other-uid'],
}) {
  return FriendCategory(
    id: id,
    ownerId: ownerId,
    name: 'Familjen',
    description: 'Vår familjegrupp',
    friendUserIds: friendUserIds,
  );
}

UserProfile _profile(String uid, {String name = 'Erik'}) {
  return UserProfile(
    uid: uid,
    displayName: name,
    email: '$uid@example.com',
    joinedAt: DateTime(2025, 1, 1),
    lastActiveAt: DateTime(2025, 1, 1),
  );
}

Widget _wrap({required Widget Function(BuildContext) appBuilder}) {
  return MaterialApp(
    locale: const Locale('sv'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Builder(builder: appBuilder),
  );
}

void main() {
  setUp(() {
    GetIt.instance.reset();
    production.ServiceLocator.reset();
  });

  tearDown(() {
    GetIt.instance.reset();
    production.ServiceLocator.reset();
  });

  /// Register a permission stub in both GetIt (DIContainer reads it) and
  /// bootstrap the production ServiceLocator for the SUT.
  void bootstrapPermissions(_StubPermissionService stub) {
    GetIt.instance.registerSingleton<PermissionService>(stub);
    production.ServiceLocator.initialize(DIContainer());
  }

  group('GroupDetailAppBar overflow menu — Report tile (BUT-511)', () {
    testWidgets(
        'non-owner sees Report tile and tapping it opens the report dialog',
        (tester) async {
      bootstrapPermissions(_StubPermissionService(uid: 'me-uid'));

      final group = _group(); // ownerId='owner-uid', current user is 'me-uid'

      await tester.pumpWidget(_wrap(
        appBuilder: (ctx) => Scaffold(
          appBar: GroupDetailAppBar.build(
            ctx,
            group: group,
            isLoading: false,
            onRefresh: () {},
            onMenuAction: (_) {},
          ),
        ),
      ));
      await tester.pump();

      // Open overflow menu.
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      // The Report tile uses the localized 'reportContent' label.
      // For Swedish: 'Rapportera'. The flag icon is the only Icons.flag_outlined
      // in the menu, so we can match by either.
      expect(find.text('Rapportera'), findsOneWidget);
      expect(find.byIcon(Icons.flag_outlined), findsOneWidget);

      // Tap the Report tile — should open ReportContentDialog's reason dialog.
      await tester.tap(find.text('Rapportera'));
      await tester.pumpAndSettle();

      // Reason dialog title proves the dialog opened.
      // (Swedish 'reportDialogTitle' = 'Rapportera innehåll')
      expect(find.text('Rapportera innehåll'), findsOneWidget);
    });

    testWidgets('owner does NOT see Report tile (self-report meaningless)',
        (tester) async {
      bootstrapPermissions(_StubPermissionService(uid: 'owner-uid'));

      final group = _group(ownerId: 'owner-uid');

      await tester.pumpWidget(_wrap(
        appBuilder: (ctx) => Scaffold(
          appBar: GroupDetailAppBar.build(
            ctx,
            group: group,
            isLoading: false,
            onRefresh: () {},
            onMenuAction: (_) {},
          ),
        ),
      ));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('Rapportera'), findsNothing);
      expect(find.byIcon(Icons.flag_outlined), findsNothing);
    });
  });

  group('GroupMemberCard — Report tile on member action menu (BUT-511)', () {
    testWidgets(
        'Report tile is reachable on another member and opens the report dialog',
        (tester) async {
      bootstrapPermissions(_StubPermissionService(uid: 'me-uid'));

      final group = _group();
      final otherMember = _profile('other-uid', name: 'Erik');

      await tester.pumpWidget(_wrap(
        appBuilder: (ctx) => Scaffold(
          body: GroupMemberCard.build(ctx, otherMember, group, () {}),
        ),
      ));
      await tester.pump();

      // Open the member action menu (the trailing PopupMenuButton).
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      // Report tile present.
      expect(find.text('Rapportera'), findsOneWidget);

      // Tap Report — opens the report-reason dialog.
      await tester.tap(find.text('Rapportera'));
      await tester.pumpAndSettle();

      expect(find.text('Rapportera innehåll'), findsOneWidget);
    });

    testWidgets('viewing own member tile does NOT show Report tile',
        (tester) async {
      bootstrapPermissions(_StubPermissionService(uid: 'me-uid'));

      final group = _group();
      final selfMember = _profile('me-uid', name: 'Mig');

      await tester.pumpWidget(_wrap(
        appBuilder: (ctx) => Scaffold(
          body: GroupMemberCard.build(ctx, selfMember, group, () {}),
        ),
      ));
      await tester.pump();

      // No menu at all — self isn't reportable AND can't be removed.
      expect(find.byIcon(Icons.more_vert), findsNothing);
    });
  });
}
