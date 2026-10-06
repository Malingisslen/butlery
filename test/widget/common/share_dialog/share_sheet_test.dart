import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/viewmodels/universal_share_dialog_viewmodel.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/share_dialog/share_sheet.dart';
import 'package:butlery/widgets/common/universal_share_dialog.dart';
import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/factories/user_profile_factory.dart';
import '../../../infrastructure/helpers/widget_test_app.dart';

class _MockShareViewModel extends Mock
    implements UniversalShareDialogViewModel {}

/// BUT-2250 (R8-8 = A): the share surface is a sheet from the bottom with a
/// handle (#delaark), at most 700 px wide, and it can be closed without an X.
void main() {
  late _MockShareViewModel viewModel;

  setUp(() {
    viewModel = _MockShareViewModel();
    when(() => viewModel.isSharing).thenReturn(false);
  });

  Future<void> openSheet(
    WidgetTester tester, {
    List<UserProfile>? friends,
    Size size = const Size(400, 800),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () => showUniversalShareSheet(
              context,
              builder: (_) => UniversalShareDialog.recipe(
                recipe: RecipeFactory.build(title: 'Kalops'),
                viewModel: viewModel,
                availableFriends: friends,
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  final friends = [
    UserProfileFactory.build(uid: 'f1', displayName: 'Erik Eriksson'),
  ];

  testWidgets('opens as a bottom sheet with a drag handle and no X', (
    tester,
  ) async {
    await openSheet(tester, friends: friends);

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(
      tester.widget<BottomSheet>(find.byType(BottomSheet)).showDragHandle,
      isTrue,
    );
    expect(find.byType(Dialog), findsNothing);
    expect(
      find.descendant(
        of: find.byType(UniversalShareDialog),
        matching: find.byWidgetPredicate(
          (w) => w is ButleryIcon && w.icon == ButleryIcons.x,
        ),
      ),
      findsNothing,
    );
  });

  testWidgets('keeps one column of at most 700 px on a wide screen', (
    tester,
  ) async {
    await openSheet(tester, friends: friends, size: const Size(1200, 900));

    expect(
      tester.getSize(find.byType(UniversalShareDialog)).width,
      AppDimensions.dialogMaxWidthLarge,
    );
  });

  group('closes without an X, in the no-friends state (no Cancel there)', () {
    testWidgets('through the handle for a screen reader', (tester) async {
      final handle = tester.ensureSemantics();
      await openSheet(tester);
      final label = MaterialLocalizations.of(
        tester.element(find.byType(UniversalShareDialog)),
      ).modalBarrierDismissLabel;

      tester.semantics.tap(
        find.semantics.byPredicate(
          (node) =>
              node.label == label &&
              node.getSemanticsData().hasAction(SemanticsAction.tap),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(UniversalShareDialog), findsNothing);
      handle.dispose();
    });

    testWidgets('through Escape', (tester) async {
      await openSheet(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byType(UniversalShareDialog), findsNothing);
    });
  });

  testWidgets('with a 300 px keyboard the Share button stays tappable and '
      'nothing overflows', (tester) async {
    await openSheet(tester, friends: friends, size: const Size(400, 700));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(UniversalShareDialog)),
    );
    final share = find.text(l10n.shareRecipeTitle).last;
    expect(tester.getRect(share).bottom, lessThanOrEqualTo(700 - 300));
    expect(share.hitTestable(), findsOneWidget);
  });
}
