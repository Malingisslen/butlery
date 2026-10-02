// BUT-2183 slice 5i: the shopping views left the old opacity steps. What each
// surface now draws is a design-system token, in both modes, and no
// translucent tint of text or status colour stands in for one.
//
// Expected colours come from the generated schemes and token members directly,
// never from `Theme.of(context)`, so a widget that reads the wrong slot cannot
// agree with itself.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/unified/operations/collaborative_shopping_operations.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_colors_dark.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/views/unified_shopping/widgets/dialogs/shopping_member_management_dialog.dart';
import 'package:butlery/views/unified_shopping/widgets/dialogs/shopping_sharing_status_dialog.dart';
import 'package:butlery/views/unified_shopping/widgets/shopping_item_tiles.dart';
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

class _RefusingService extends Fake implements UnifiedShoppingService {
  final _ops = _RefusingOps();

  @override
  CollaborativeShoppingOperations get collaborative => _ops;

  @override
  String? consumeMutationError() => null;
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

Color _dangerTint(Brightness b) => b == Brightness.dark
    ? AppColorsDark.surfaceTintDanger
    : AppColors.surfaceTintDanger;

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

    group('shopping surfaces in ${brightness.name} mode', () {
      testWidgets('the sharing dialog cards are raised, the avatars on paper', (
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
        final cards = tester.widgetList<Card>(find.byType(Card)).toList();
        expect(cards, hasLength(4));
        for (final card in cards) {
          expect(card.color, cs.surfaceContainerHighest);
        }

        // The avatar sits on a raised card, so it takes the base surface.
        final avatars = tester
            .widgetList<CircleAvatar>(find.byType(CircleAvatar))
            .toList();
        expect(avatars, hasLength(2));
        for (final avatar in avatars) {
          expect(avatar.backgroundColor, cs.surface);
        }
      });

      testWidgets('the member dialog avatars sit on paper inside raised rows', (
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
            ),
            brightness,
          ),
        );
        await tester.pumpAndSettle();

        // Owner row, Bob's row and the friend row.
        final avatars = tester
            .widgetList<CircleAvatar>(find.byType(CircleAvatar))
            .toList();
        expect(avatars, hasLength(3));
        for (final avatar in avatars) {
          expect(avatar.backgroundColor, cs.surface);
        }
      });

      testWidgets('the sharing dialog draws the Redigera role in ink with a '
          'saffron glyph', (tester) async {
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
          tester.widget<Text>(find.text('Redigera')).style?.color,
          cs.onSurface,
        );
        expect(
          tester.widget<Icon>(find.byIcon(ButleryIcons.pencil)).color,
          cs.secondary,
        );
      });

      testWidgets('the member dialog draws the Redigera role in ink with a '
          'saffron glyph', (tester) async {
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
            ),
            brightness,
          ),
        );
        await tester.pumpAndSettle();

        final role = find.text('Redigera').hitTestable();
        expect(role, findsOneWidget);
        final style = DefaultTextStyle.of(tester.element(role)).style;
        expect(style.color, cs.onSurface);
        expect(
          tester.widget<Icon>(find.byIcon(ButleryIcons.pencil)).color,
          cs.secondary,
        );
      });

      testWidgets('a refused change is a tinted notice with its own text', (
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
        expect(
          tester.widget<Text>(noticeText).style?.color,
          cs.onErrorContainer,
        );

        final box = tester.widget<Container>(
          find.ancestor(of: noticeText, matching: find.byType(Container)).first,
        );
        final decoration = box.decoration! as BoxDecoration;
        expect(decoration.color, _dangerTint(brightness));
        expect(decoration.border, isNull);
      });

      testWidgets('a ticked-off item keeps its note and trash at full colour', (
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
          tester.widget<Icon>(find.byIcon(ButleryIcons.trash2)).color,
          cs.onSurfaceVariant,
        );
      });
    });
  }
}
