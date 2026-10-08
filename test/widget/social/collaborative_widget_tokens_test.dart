// BUT-2183 5h: the collaborative indicators and the group widgets leave the
// old opacity steps. Notices are the mode's surface tint with no border
// (B83-2); fills are the raised surface (or surface.base when the parent is
// already raised); borders are outlineVariant; on the ink bar the badge takes
// the ink-raised pair. Each test runs in both modes.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/permissions/edit_mode.dart';
import 'package:butlery/services/group_shared_content_service.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/social/collaborative/components/collaborative_connection_widgets.dart';
import 'package:butlery/widgets/social/collaborative/components/collaborative_live_widgets.dart';
import 'package:butlery/widgets/social/collaborative/components/collaborative_participants_widgets.dart';
import 'package:butlery/widgets/social/collaborative/components/collaborative_permissions_widgets.dart';
import 'package:butlery/widgets/social/collaborative/components/collaborative_status_widgets.dart';
import 'package:butlery/widgets/social/groups/group_shared_content_section.dart';
import 'package:butlery/widgets/social/groups/shared/group_dialog_components.dart';
import 'package:butlery/widgets/social/groups/shared_content_card.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/factories/social_factory.dart';

class _FakeContentService extends Fake implements GroupSharedContentService {
  _FakeContentService(this.items);
  final List<SharedContentItem> items;

  @override
  Stream<List<SharedContentItem>> streamSharedRecipes(FriendCategory group) =>
      Stream.value(items);

  @override
  Stream<List<SharedContentItem>> streamSharedMenus(FriendCategory group) =>
      Stream.value(const []);

  @override
  Stream<List<SharedContentItem>> streamSharedShoppingLists(
    FriendCategory group,
  ) => Stream.value(const []);
}

SharedContentItem _item(String type) => SharedContentItem(
  id: 'i-$type',
  title: 'Delad $type',
  type: type,
  sharedByUserId: 'u1',
  sharedByDisplayName: 'Malin',
  sharedAt: DateTime(2026, 9, 1),
  data: const {},
);

Future<void> _pump(WidgetTester tester, ThemeData theme, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      locale: const Locale('sv'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

/// The nearest Container above [of] that paints a BoxDecoration.
BoxDecoration _decorationAbove(WidgetTester tester, Finder of) {
  final container = find
      .ancestor(
        of: of,
        matching: find.byWidgetPredicate(
          (w) => w is Container && w.decoration is BoxDecoration,
        ),
      )
      .first;
  return tester.widget<Container>(container).decoration! as BoxDecoration;
}

Color? _textColor(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style?.color;

void main() {
  final sv = AppLocalizationsSv();

  setUpAll(() {
    production.ServiceLocator.initialize(DIContainer());
  });

  setUp(() async {
    await TestServiceLocator.initialize();
  });

  tearDown(() async {
    await TestServiceLocator.reset();
  });

  for (final (mode, theme) in [
    ('light', AppTheme.lightTheme),
    ('dark', AppTheme.darkTheme),
  ]) {
    final cs = theme.colorScheme;
    final modeColors = ModeColors.of(theme.brightness);

    group('collaborative indicators, $mode', () {
      testWidgets('online pill is the success tint with onSuccessContainer '
          'text and no border', (tester) async {
        await _pump(
          tester,
          theme,
          CollaborativeConnectionWidgets.connectionStatus(
            isOnline: true,
            statusText: '',
          ),
        );
        final decoration = _decorationAbove(
          tester,
          find.text(sv.collaborativeOnline),
        );
        expect(decoration.color, modeColors.surfaceTintSuccess);
        expect(decoration.border, isNull);
        expect(
          _textColor(tester, sv.collaborativeOnline),
          modeColors.onSuccessContainer,
        );
      });

      testWidgets('offline banner is the danger tint with onErrorContainer '
          'text and no border', (tester) async {
        await _pump(
          tester,
          theme,
          CollaborativeConnectionWidgets.connectionStatus(
            isOnline: false,
            statusText: 'Ingen kontakt',
            showRetryButton: true,
            onRetry: () {},
          ),
        );
        final decoration = _decorationAbove(
          tester,
          find.text(sv.collaborativeOffline),
        );
        expect(decoration.color, modeColors.surfaceTintDanger);
        expect(decoration.border, isNull);
        expect(
          _textColor(tester, sv.collaborativeOffline),
          cs.onErrorContainer,
        );
        expect(_textColor(tester, 'Ingen kontakt'), cs.onErrorContainer);
        expect(_textColor(tester, sv.commonRetry), cs.onErrorContainer);
      });

      testWidgets('edit indicator is the warning tint with textWarning text '
          'and no border', (tester) async {
        await _pump(
          tester,
          theme,
          CollaborativeLiveWidgets.editIndicator(
            editorName: 'Per',
            editingWhat: 'titeln',
          ),
        );
        await tester.pump(const Duration(seconds: 1));
        final label = find.text('Per redigerar titeln');
        final decoration = _decorationAbove(tester, label);
        expect(decoration.color, modeColors.surfaceTintWarning);
        expect(decoration.border, isNull);
        expect(
          tester.widget<Text>(label).style?.color,
          AppModeColors.textWarning(theme.brightness),
        );
      });

      for (final (editMode, fill, foreground) in [
        (EditMode.owner, cs.surfaceContainerHighest, cs.onSurface),
        (EditMode.edit, cs.surfaceContainerHighest, cs.onSurface),
        (
          EditMode.collaborative,
          modeColors.surfaceTintSuccess,
          modeColors.onSuccessContainer,
        ),
        (
          EditMode.view,
          modeColors.surfaceTintWarning,
          AppModeColors.textWarning(theme.brightness),
        ),
        (
          EditMode.readOnlyWithFork,
          modeColors.surfaceTintWarning,
          AppModeColors.textWarning(theme.brightness),
        ),
        (EditMode.noAccess, modeColors.surfaceTintDanger, cs.onErrorContainer),
      ]) {
        testWidgets('permissions banner for ${editMode.name}: tint with no '
            'border, text and glyph in the notice colour', (tester) async {
          await _pump(
            tester,
            theme,
            Builder(
              builder: (ctx) =>
                  CollaborativePermissionsWidgets.permissionsBanner(
                    context: ctx,
                    editMode: editMode,
                  ),
            ),
          );
          final label = find.text(editMode.description);
          final decoration = _decorationAbove(tester, label);
          expect(decoration.color, fill);
          expect(decoration.border, isNull);
          expect(tester.widget<Text>(label).style?.color, foreground);
          final glyph = tester.widget<ButleryIcon>(find.byType(ButleryIcon));
          expect(glyph.color, foreground);
        });
      }

      testWidgets('status badge off the ink bar is raised with an '
          'outlineVariant line', (tester) async {
        await _pump(
          tester,
          theme,
          CollaborativeStatusWidgets.statusBadge(text: 'Delat'),
        );
        final decoration = _decorationAbove(tester, find.text('Delat'));
        expect(decoration.color, cs.surfaceContainerHighest);
        expect(
          (decoration.border! as Border).top.color,
          cs.outlineVariant,
        );
        expect(_textColor(tester, 'Delat'), cs.onSurface);
      });

      testWidgets('status badge on the ink bar is ink-raised with the ink '
          'border and paper text', (tester) async {
        await _pump(
          tester,
          theme,
          CollaborativeStatusWidgets.statusBadge(
            text: 'Delat',
            onInk: true,
          ),
        );
        final decoration = _decorationAbove(tester, find.text('Delat'));
        expect(decoration.color, AppModeColors.surfaceRaisedOnInk());
        expect(
          (decoration.border! as Border).top.color,
          AppModeColors.borderOnInk(),
        );
        expect(_textColor(tester, 'Delat'), cs.onPrimary);
      });

      testWidgets('banner is raised with an outlineVariant bottom line', (
        tester,
      ) async {
        await _pump(
          tester,
          theme,
          CollaborativeStatusWidgets.banner(
            title: 'Redigerar tillsammans',
            subtitle: 'Synkas automatiskt',
          ),
        );
        final decoration = _decorationAbove(
          tester,
          find.text('Redigerar tillsammans'),
        );
        expect(decoration.color, cs.surfaceContainerHighest);
        expect(
          (decoration.border! as Border).bottom.color,
          cs.outlineVariant,
        );
      });

      testWidgets('the participant skeleton and the +N chip stand on '
          'surface.base', (tester) async {
        await _pump(
          tester,
          theme,
          Builder(
            builder: (ctx) => CollaborativeParticipantsWidgets.participantsList(
              context: ctx,
              contentId: 'r1',
            ),
          ),
        );
        final skeletons = tester
            .widgetList<Container>(find.byType(Container))
            .where((c) => c.decoration is BoxDecoration)
            .map((c) => (c.decoration! as BoxDecoration).color)
            .toList();
        expect(skeletons, [cs.surface, cs.surface]);
        await tester.pump();

        await _pump(
          tester,
          theme,
          CollaborativeParticipantsWidgets.avatarRow(
            participants: [
              SocialFactory.createUserProfile(uid: 'a', displayName: 'Anna'),
              SocialFactory.createUserProfile(uid: 'b', displayName: 'Bo'),
            ],
            maxVisible: 1,
          ),
        );
        final chip = _decorationAbove(tester, find.text('+1'));
        expect(chip.color, cs.surface);
      });
    });

    group('group widgets, $mode', () {
      testWidgets('error box is the danger tint with onErrorContainer text '
          'and glyph and no border', (tester) async {
        await _pump(
          tester,
          theme,
          const ErrorDisplayWidget(errorMessage: 'Något gick fel'),
        );
        final decoration = _decorationAbove(
          tester,
          find.text('Något gick fel'),
        );
        expect(decoration.color, modeColors.surfaceTintDanger);
        expect(decoration.border, isNull);
        expect(_textColor(tester, 'Något gick fel'), cs.onErrorContainer);
        expect(
          tester.widget<ButleryIcon>(find.byType(ButleryIcon)).color,
          cs.onErrorContainer,
        );
      });

      testWidgets('warning box is the warning tint with textWarning text '
          'and glyph and no border', (tester) async {
        await _pump(
          tester,
          theme,
          const WarningDisplayWidget(warningMessage: 'Var försiktig'),
        );
        final decoration = _decorationAbove(tester, find.text('Var försiktig'));
        final warning = AppModeColors.textWarning(theme.brightness);
        expect(decoration.color, modeColors.surfaceTintWarning);
        expect(decoration.border, isNull);
        expect(_textColor(tester, 'Var försiktig'), warning);
        expect(
          tester.widget<ButleryIcon>(find.byType(ButleryIcon)).color,
          warning,
        );
      });

      testWidgets('shared-content card: tile and avatar are surface.base on '
          'the raised card, type labels are text colours', (tester) async {
        for (final (type, label, color) in [
          ('menu', sv.groupContentTypeMenu, modeColors.onSuccessContainer),
          (
            'shopping_list',
            sv.groupContentTypeShoppingList,
            AppModeColors.textWarning(theme.brightness),
          ),
        ]) {
          await _pump(tester, theme, SharedContentCard(item: _item(type)));
          final tile = _decorationAbove(tester, find.byType(ButleryIcon).first);
          expect(tile.color, cs.surface, reason: type);
          expect(_textColor(tester, label), color, reason: type);
          final avatar = tester.widget<CircleAvatar>(
            find.byType(CircleAvatar),
          );
          expect(avatar.backgroundColor, cs.surface, reason: type);
        }
      });

      testWidgets('shared-content section: the count pill is the raised '
          'surface', (tester) async {
        TestServiceLocator.registerMock<GroupSharedContentService>(
          _FakeContentService([_item('recipe'), _item('recipe')]),
        );
        await _pump(
          tester,
          theme,
          SizedBox(
            height: 600,
            child: GroupSharedContentSection(
              group: SocialFactory.createFriendCategory(name: 'Klubben'),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();
        final decoration = _decorationAbove(tester, find.text('2'));
        expect(decoration.color, cs.surfaceContainerHighest);
      });
    });
  }
}
