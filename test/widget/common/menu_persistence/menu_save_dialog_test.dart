/// Widget tests for SaveMenuDialog (menu_save_dialog.dart).
///
/// Behaviours covered:
///   1. Title + summary line render from l10n with the viewmodel's counts.
///   2. Name + comment + share fields are present with the right labels.
///   3. Toggling the share switch reveals friend selection + share message.
///   4. Empty `availableFriends` shows the localized "no friends" copy.
///   5. Name validation: empty submit produces the localized error.
///   6. Successful save calls viewModel.saveMenuWithNameAndComment with the
///      typed-in name, comment, share flag, and selected friend ids.
///
/// Mocktail fakes the MenuViewModel. We use a large surface (1200x1800) so
/// the AlertDialog + nested SingleChildScrollView/ListView don't trip the
/// intrinsic-dimension test pass when the share section unfolds.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/menu_viewmodel.dart';
import 'package:butlery/widgets/common/menu_persistence/menu_save_dialog.dart';

class _FakeMenuViewModel extends Mock implements MenuViewModel {}

class _FakeFriend {
  _FakeFriend(this.uid, this.displayName);
  final String uid;
  final String displayName;
}

/// Wraps a child in MaterialApp with sv locale + l10n delegates.
Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.lightTheme,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('sv'),
  home: Scaffold(body: child),
);

/// AlertDialog + nested scroll viewports want generous logical pixels in
/// flutter_test or the intrinsic pass throws. Matches the helper from
/// confirmation_dialogs_test.dart.
void _useLargeSurface(WidgetTester tester) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(1200, 1800);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Builds a Trigger that opens the SaveMenuDialog inside a route — needed so
/// `Navigator.pop(context)` from the dialog has somewhere to pop to and so
/// `ScaffoldMessenger.of` resolves in the dialog's tree.
Widget _trigger({
  required MenuViewModel vm,
  List<dynamic>? friends,
}) {
  return Builder(
    builder: (ctx) => ElevatedButton(
      onPressed: () => showDialog<void>(
        context: ctx,
        builder: (_) => SaveMenuDialog(
          viewModel: vm,
          availableFriends: friends,
        ),
      ),
      child: const Text('Show'),
    ),
  );
}

MenuViewModel _vm({
  int totalRecipes = 7,
  int categories = 3,
  String? error,
}) {
  final vm = _FakeMenuViewModel();
  when(() => vm.totalRecipeCount).thenReturn(totalRecipes);
  // `menu` returns Map<String, List<Recipe>> — its .length is what the
  // dialog reads for the category count.
  when(() => vm.menu).thenReturn({
    for (var i = 0; i < categories; i++) 'cat$i': const <Recipe>[],
  });
  when(() => vm.error).thenReturn(error);
  return vm;
}

void main() {
  group('SaveMenuDialog', () {
    testWidgets('renders title, summary line, and the three core fields', (
      tester,
    ) async {
      _useLargeSurface(tester);
      final vm = _vm(totalRecipes: 7, categories: 3);

      await tester.pumpWidget(_wrap(_trigger(vm: vm)));
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      // Title from menuSaveTitle
      expect(find.text('Spara meny'), findsOneWidget);
      // Summary line from menuToSave + menuRecipesInCategories
      expect(find.text('Meny att spara'), findsOneWidget);
      expect(find.text('7 recept i 3 kategorier'), findsOneWidget);

      // Name + comment labels
      expect(find.text('Menynamn'), findsOneWidget);
      expect(find.text('Kommentar (valfritt)'), findsOneWidget);

      // Share switch label
      expect(find.text('Dela med vänner'), findsOneWidget);
    });

    testWidgets('share section is hidden until the switch is toggled on', (
      tester,
    ) async {
      _useLargeSurface(tester);
      final vm = _vm();

      await tester.pumpWidget(_wrap(_trigger(vm: vm)));
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      // Off by default → friend-selection header absent.
      expect(find.text('Välj vänner att dela med'), findsNothing);
      expect(find.byType(SwitchListTile), findsOneWidget);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(find.text('Välj vänner att dela med'), findsOneWidget);
      // menuShareMessageLabel
      expect(find.text('Delningsmeddelande'), findsOneWidget);
    });

    testWidgets(
      'empty availableFriends list shows the localized "no friends" copy',
      (tester) async {
        _useLargeSurface(tester);
        final vm = _vm();

        await tester.pumpWidget(_wrap(_trigger(vm: vm, friends: const [])));
        await tester.tap(find.text('Show'));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(Switch));
        await tester.pumpAndSettle();

        expect(find.text('Inga vänner tillgängliga'), findsOneWidget);
      },
    );

    testWidgets(
      'non-empty availableFriends renders one CheckboxListTile per friend',
      (tester) async {
        _useLargeSurface(tester);
        final vm = _vm();
        final friends = [
          _FakeFriend('u1', 'Anna'),
          _FakeFriend('u2', 'Bertil'),
        ];

        await tester.pumpWidget(_wrap(_trigger(vm: vm, friends: friends)));
        await tester.tap(find.text('Show'));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(Switch));
        await tester.pumpAndSettle();

        expect(find.byType(CheckboxListTile), findsNWidgets(2));
        expect(find.text('Anna'), findsOneWidget);
        expect(find.text('Bertil'), findsOneWidget);
      },
    );

    testWidgets(
      'submitting an empty name triggers the localized required-field error',
      (tester) async {
        _useLargeSurface(tester);
        final vm = _vm();

        await tester.pumpWidget(_wrap(_trigger(vm: vm)));
        await tester.tap(find.text('Show'));
        await tester.pumpAndSettle();

        // Tap the Spara button without filling the name.
        await tester.tap(find.widgetWithText(FilledButton, 'Spara'));
        await tester.pumpAndSettle();

        // FormValidators.required wraps the fieldName in
        // validationFieldCannotBeEmpty → "{fieldName} får inte vara tom". The
        // dialog passes menuNameRequired ("Menynamn krävs") as the fieldName,
        // so the rendered error is the composed string below.
        expect(find.text('Menynamn krävs får inte vara tom'), findsOneWidget);
        // saveMenuWithNameAndComment must NOT have been called.
        verifyNever(
          () => vm.saveMenuWithNameAndComment(
            any(),
            any(),
            shareWithFriends: any(named: 'shareWithFriends'),
            selectedFriendIds: any(named: 'selectedFriendIds'),
            shareMessage: any(named: 'shareMessage'),
          ),
        );
      },
    );

    testWidgets(
      'valid submit forwards name, comment, and share state to the viewmodel',
      (tester) async {
        _useLargeSurface(tester);
        final vm = _vm();
        when(
          () => vm.saveMenuWithNameAndComment(
            any(),
            any(),
            shareWithFriends: any(named: 'shareWithFriends'),
            selectedFriendIds: any(named: 'selectedFriendIds'),
            shareMessage: any(named: 'shareMessage'),
          ),
        ).thenAnswer((_) async => true);

        await tester.pumpWidget(_wrap(_trigger(vm: vm)));
        await tester.tap(find.text('Show'));
        await tester.pumpAndSettle();

        // Fill name + comment. Two TextFormFields visible (no share section).
        final fields = find.byType(TextFormField);
        expect(fields, findsNWidgets(2));
        await tester.enterText(fields.at(0), 'Min veckomeny');
        await tester.enterText(fields.at(1), 'God och billig');

        await tester.tap(find.widgetWithText(FilledButton, 'Spara'));
        await tester.pump(); // start save
        await tester.pump(); // resolve future

        final captured = verify(
          () => vm.saveMenuWithNameAndComment(
            captureAny(),
            captureAny(),
            shareWithFriends: captureAny(named: 'shareWithFriends'),
            selectedFriendIds: captureAny(named: 'selectedFriendIds'),
            shareMessage: captureAny(named: 'shareMessage'),
          ),
        ).captured;

        expect(captured[0], 'Min veckomeny');
        expect(captured[1], 'God och billig');
        expect(captured[2], false); // shareWithFriends default
        expect(captured[3], <String>[]); // no selected friend ids
        // Default share message is menuShareDefaultMessage, set in build().
        expect(captured[4], 'Kolla min veckomeny!');
      },
    );

    testWidgets(
      'checking a friend includes their uid in the selectedFriendIds arg',
      (tester) async {
        _useLargeSurface(tester);
        final vm = _vm();
        when(
          () => vm.saveMenuWithNameAndComment(
            any(),
            any(),
            shareWithFriends: any(named: 'shareWithFriends'),
            selectedFriendIds: any(named: 'selectedFriendIds'),
            shareMessage: any(named: 'shareMessage'),
          ),
        ).thenAnswer((_) async => true);

        await tester.pumpWidget(
          _wrap(
            _trigger(
              vm: vm,
              friends: [_FakeFriend('u1', 'Anna'), _FakeFriend('u2', 'Bertil')],
            ),
          ),
        );
        await tester.tap(find.text('Show'));
        await tester.pumpAndSettle();

        // Fill name (required), then toggle share + check Bertil.
        await tester.enterText(find.byType(TextFormField).at(0), 'Veckomeny');
        await tester.tap(find.byType(Switch));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Bertil'));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(FilledButton, 'Spara'));
        await tester.pump();
        await tester.pump();

        final captured = verify(
          () => vm.saveMenuWithNameAndComment(
            captureAny(),
            captureAny(),
            shareWithFriends: captureAny(named: 'shareWithFriends'),
            selectedFriendIds: captureAny(named: 'selectedFriendIds'),
            shareMessage: captureAny(named: 'shareMessage'),
          ),
        ).captured;
        expect(captured[2], true);
        expect(captured[3], ['u2']);
      },
    );

    testWidgets(
      'cancel button pops the dialog without invoking the viewmodel',
      (tester) async {
        _useLargeSurface(tester);
        final vm = _vm();

        await tester.pumpWidget(_wrap(_trigger(vm: vm)));
        await tester.tap(find.text('Show'));
        await tester.pumpAndSettle();

        expect(find.byType(SaveMenuDialog), findsOneWidget);

        await tester.tap(find.widgetWithText(TextButton, 'Avbryt'));
        await tester.pumpAndSettle();

        expect(find.byType(SaveMenuDialog), findsNothing);
        verifyNever(
          () => vm.saveMenuWithNameAndComment(
            any(),
            any(),
            shareWithFriends: any(named: 'shareWithFriends'),
            selectedFriendIds: any(named: 'selectedFriendIds'),
            shareMessage: any(named: 'shareMessage'),
          ),
        );
      },
    );
  });
}
