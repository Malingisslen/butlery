// BUT-2183 slice 5i: the shopping views left the old opacity steps. What each
// surface now draws is a design-system token, in both modes, and no
// translucent tint of text or status colour stands in for one.
//
// Expected colours come from the generated schemes and token members directly,
// never from `Theme.of(context)`, so a widget that reads the wrong slot cannot
// agree with itself.

import 'package:butlery/widgets/common/avatar_circle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/cards/styled_card.dart';
import 'package:get_it/get_it.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/social_request.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/unified/operations/collaborative_shopping_operations.dart';
import 'package:butlery/services/unified/operations/list_invitation_operations.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/views/unified_shopping/widgets/dialogs/shopping_member_management_dialog.dart';
import 'package:butlery/views/unified_shopping/widgets/dialogs/shopping_sharing_status_dialog.dart';
import 'package:butlery/views/unified_shopping/widgets/shopping_item_tiles.dart';
import 'package:butlery/widgets/common/feedback/inline_error.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

import '../../helpers/user_profile_factory.dart';
import '../../infrastructure/mocks/production_mocks.dart';

const _ownerId = 'owner-uid';

/// Every membership change refuses, so the dialog shows its error notice.
class _RefusingOps extends Fake implements CollaborativeShoppingOperations {
  @override
  Future<bool> removeMember({
    required String listId,
    required String userId,
  }) async => false;
}

/// The dialogs here are about surfaces, not invitations: none are pending.
class _NoInvitations extends Fake implements ListInvitationOperations {
  @override
  String? get currentUserId => _ownerId;

  @override
  Stream<List<SocialRequest>> pendingSentForList(String listId) =>
      const Stream.empty();
}

class _RefusingService extends Fake implements UnifiedShoppingService {
  final _ops = _RefusingOps();

  @override
  CollaborativeShoppingOperations get collaborative => _ops;

  @override
  String? consumeMutationError() => null;
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (la > lb ? la + 0.05 : lb + 0.05) / (la > lb ? lb + 0.05 : la + 0.05);
}

Widget _app(Widget child, Brightness brightness) => MaterialApp(
  locale: const Locale('sv'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  theme: brightness == Brightness.dark
      ? AppTheme.darkTheme
      : AppTheme.lightTheme,
  home: Scaffold(body: child),
);

ColorScheme _scheme(Brightness b) => b == Brightness.dark
    ? AppColors.darkColorScheme
    : AppColors.lightColorScheme;

UnifiedShoppingList _sharedList() => UnifiedShoppingList(
  id: 'list-1',
  name: 'Familjehandling',
  ownerId: _ownerId,
  ownerDisplayName: 'Malin',
  type: ListType.collaborative,
  memberPermissions: const {
    _ownerId: SharedListPermission.admin,
    'bob': SharedListPermission.edit,
  },
  lastActivityAt: DateTime(2026, 9, 1),
  lastActivityByDisplayName: 'Bob',
);

void main() {
  setUpAll(() {
    production.ServiceLocator.initialize(DIContainer());
  });

  setUp(() {
    final permission = FakePermissionService()
      ..setPermissionState(currentUserId: _ownerId);
    if (GetIt.instance.isRegistered<PermissionService>()) {
      GetIt.instance.unregister<PermissionService>();
    }
    if (GetIt.instance.isRegistered<UserService>()) {
      GetIt.instance.unregister<UserService>();
    }
    if (GetIt.instance.isRegistered<UnifiedShoppingService>()) {
      GetIt.instance.unregister<UnifiedShoppingService>();
    }
    GetIt.instance.registerSingleton<PermissionService>(permission);
    GetIt.instance.registerSingleton<UserService>(MockUserService());
    GetIt.instance.registerSingleton<UnifiedShoppingService>(
      _RefusingService(),
    );
  });

  tearDown(() {
    if (GetIt.instance.isRegistered<PermissionService>()) {
      GetIt.instance.unregister<PermissionService>();
    }
    if (GetIt.instance.isRegistered<UserService>()) {
      GetIt.instance.unregister<UserService>();
    }
    if (GetIt.instance.isRegistered<UnifiedShoppingService>()) {
      GetIt.instance.unregister<UnifiedShoppingService>();
    }
  });

  for (final brightness in Brightness.values) {
    final cs = _scheme(brightness);
    final editGlyph = brightness == Brightness.dark
        ? AppColors.darkColorScheme.secondary
        : AppColors.lightColorScheme.onSurface;

    group('shopping surfaces in ${brightness.name} mode', () {
      testWidgets('the sharing dialog cards are paper, the avatars ink', (
        tester,
      ) async {
        await tester.pumpWidget(
          _app(
            ShoppingShareStatusDialog(
              list: _sharedList(),
              userDisplayNames: const {_ownerId: 'Malin', 'bob': 'Bob'},
            ),
            brightness,
          ),
        );
        await tester.pumpAndSettle();

        // Info, your permission, members, recent activity.
        expect(find.byType(StyledCard), findsNWidgets(4));
        expect(
          Theme.of(
            tester.element(find.byType(StyledCard).first),
          ).cardTheme.color,
          cs.surface,
        );

        // The card is paper with a border, so the avatar is the ink circle.
        final avatars = tester
            .widgetList<AvatarCircle>(find.byType(AvatarCircle))
            .toList();
        expect(avatars, hasLength(2));
        for (final avatar in avatars) {
          expect(avatar.tone, AvatarCircleTone.ink);
        }
      });

      testWidgets(
        'the member rows draw ink avatars, the friend row a paper one',
        (
          tester,
        ) async {
          tester.view.physicalSize = const Size(1000, 1800);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });
          final UserProfile friend = testUserProfile(
            uid: 'cecilia',
            displayName: 'Cecilia',
          );

          await tester.pumpWidget(
            _app(
              ShoppingMemberManagementDialog(
                list: _sharedList(),
                userDisplayNames: const {
                  _ownerId: 'Malin',
                  'bob': 'Bob',
                  'cecilia': 'Cecilia',
                },
                availableFriends: [friend],
                invitations: _NoInvitations(),
              ),
              brightness,
            ),
          );
          await tester.pumpAndSettle();

          // Owner row, Bob's row and the friend row.
          final avatars = tester
              .widgetList<AvatarCircle>(find.byType(AvatarCircle))
              .toList();
          expect(avatars, hasLength(3));
          // The member rows have no fill of their own, so a paper circle would
          // vanish into the dialog; the friend row is a card.
          for (final avatar in avatars.take(2)) {
            expect(avatar.tone, AvatarCircleTone.ink);
          }
          expect(avatars.last.tone, AvatarCircleTone.paper);
          expect(_circleColor(tester, avatars.last), cs.surface);
        },
      );

      testWidgets(
        'the sharing dialog draws the Redigera role in ink, its glyph '
        'in ink in light and saffron in dark',
        (tester) async {
          await tester.pumpWidget(
            _app(
              ShoppingShareStatusDialog(
                list: _sharedList(),
                userDisplayNames: const {_ownerId: 'Malin', 'bob': 'Bob'},
              ),
              brightness,
            ),
          );
          await tester.pumpAndSettle();

          expect(
            tester.widget<Text>(find.text('Redigerare')).style?.color,
            cs.onSurface,
          );
          expect(
            tester.widget<Icon>(find.byIcon(ButleryIcons.pencil)).color,
            editGlyph,
          );
          expect(
            _contrast(editGlyph, cs.surfaceContainerHighest),
            greaterThanOrEqualTo(3),
          );
          expect(
            _contrast(editGlyph, cs.surface),
            greaterThanOrEqualTo(3),
          );
        },
      );

      testWidgets('the sharing dialog draws the own-permission Redigera '
          'permission glyph the same way', (tester) async {
        GetIt.instance.unregister<PermissionService>();
        GetIt.instance.registerSingleton<PermissionService>(
          FakePermissionService()..setPermissionState(currentUserId: 'bob'),
        );
        await tester.pumpWidget(
          _app(
            ShoppingShareStatusDialog(
              list: _sharedList(),
              userDisplayNames: const {_ownerId: 'Malin', 'bob': 'Bob'},
            ),
            brightness,
          ),
        );
        await tester.pumpAndSettle();

        final glyphs = tester
            .widgetList<Icon>(find.byIcon(ButleryIcons.pencil))
            .toList();
        expect(glyphs, hasLength(2));
        for (final glyph in glyphs) {
          expect(glyph.color, editGlyph);
        }
      });

      testWidgets('the member dialog draws the Redigera role in ink, its glyph '
          'in ink in light and saffron in dark', (tester) async {
        tester.view.physicalSize = const Size(1000, 1800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          _app(
            ShoppingMemberManagementDialog(
              list: _sharedList(),
              userDisplayNames: const {_ownerId: 'Malin', 'bob': 'Bob'},
              availableFriends: const [],
              invitations: _NoInvitations(),
            ),
            brightness,
          ),
        );
        await tester.pumpAndSettle();

        // Scoped to the member's role picker: the invite-level picker below
        // also reads "Redigera".
        final role = find
            .descendant(
              of: find.byType(DropdownButton<SharedListPermission>),
              matching: find.text('Redigerare'),
            )
            .hitTestable();
        expect(role, findsOneWidget);
        final style = DefaultTextStyle.of(tester.element(role)).style;
        expect(style.color, cs.onSurface);
        expect(
          tester.widget<Icon>(find.byIcon(ButleryIcons.pencil)).color,
          editGlyph,
        );
        expect(
          _contrast(editGlyph, cs.surfaceContainerHighest),
          greaterThanOrEqualTo(3),
        );
        expect(
          _contrast(editGlyph, cs.surface),
          greaterThanOrEqualTo(3),
        );
      });

      testWidgets('a refused change is the shared error box, with its text', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(1000, 1800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          _app(
            ShoppingMemberManagementDialog(
              list: _sharedList(),
              userDisplayNames: const {_ownerId: 'Malin', 'bob': 'Bob'},
              availableFriends: const [],
              invitations: _NoInvitations(),
            ),
            brightness,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(ButleryIcons.userMinus));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ta bort').last);
        await tester.pumpAndSettle();

        final noticeText = find.text('Kunde inte ta bort medlem');
        expect(noticeText, findsOneWidget);
        expect(tester.widget<Text>(noticeText).style?.color, cs.onSurface);

        final box = tester.widget<Material>(find.byKey(InlineError.boxKey));
        final shape = box.shape! as RoundedRectangleBorder;
        expect(box.color, cs.surface);
        expect(shape.side.color, cs.error);
        expect(
          find.ancestor(
            of: noticeText,
            matching: find.byWidgetPredicate(
              (w) => w is Semantics && w.properties.role == SemanticsRole.alert,
            ),
          ),
          findsOneWidget,
        );
      });

      testWidgets('a ticked-off item keeps its note and menu at full colour', (
        tester,
      ) async {
        await tester.pumpWidget(
          _app(
            ShoppingItemTile(
              item: UnifiedShoppingItem(
                id: 'i1',
                name: 'Ägg',
                amount: 12,
                unit: 'st',
                category: 'Mejeri',
                bought: true,
                note: 'Ekologiska',
              ),
              isCompleted: true,
              onItemTap: (_) {},
              onEditItem: (_) {},
              onDeleteItem: (_) {},
            ),
            brightness,
          ),
        );
        await tester.pumpAndSettle();

        expect(
          tester.widget<Text>(find.text('Ekologiska')).style?.color,
          cs.onSurfaceVariant,
        );
        expect(
          tester.widget<Icon>(find.byIcon(ButleryIcons.moreVertical)).color,
          cs.onSurfaceVariant,
        );
      });
    });
  }
}

Color? _circleColor(WidgetTester tester, AvatarCircle avatar) => tester
    .widgetList<Container>(
      find.descendant(
        of: find.byWidget(avatar),
        matching: find.byType(Container),
      ),
    )
    .map((c) => c.decoration)
    .whereType<BoxDecoration>()
    .first
    .color;
