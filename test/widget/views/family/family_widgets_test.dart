/// Widget tests for the "Min familj" presentation widgets.
///
/// These take plain models (no ViewModel / ServiceLocator), so they verify the
/// row rendering contract directly: a family member shows its name and a
/// line with its age band and allergens, is tappable, and carries the edit
/// accessibility label; an account row says who is you and who is admin. The screen's logic is covered by the
/// MinFamiljViewModel unit tests.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/utils/distinct_initials.dart';
import 'package:butlery/models/diner_profile.dart';
import 'package:butlery/models/household_roster_member.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/views/family/family_widgets.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';
import '../../../infrastructure/helpers/ink_fill.dart';

DinerProfile _diner({
  String name = 'Liam',
  DinerAgeBand band = DinerAgeBand.child,
  Set<String> allergens = const {},
}) => DinerProfile.create(
  householdId: 'hh-1',
  name: name,
  ageBand: band,
  createdBy: 'user-malin',
  allergenPreferences: allergens.isEmpty
      ? null
      : UserAllergenPreferences(
          trackedAllergens: allergens,
          trackedDietary: const {},
        ),
);

void main() {
  group('FamilyAvatar initials', () {
    testWidgets('falls back to the name when no initials are passed', (
      tester,
    ) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: const FamilyAvatar(name: 'Anna Berg', color: Colors.blue),
        ),
      );
      expect(find.text('AB'), findsOneWidget);
    });

    testWidgets('rows given list-wide initials show two different texts', (
      tester,
    ) async {
      final initials = distinctInitials(['Test 16', 'Test 17']);
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Column(
            children: [
              FamilyMemberRow(
                profile: _diner(name: 'Test 16'),
                onTap: () {},
                initials: initials[0],
              ),
              FamilyMemberRow(
                profile: _diner(name: 'Test 17'),
                onTap: () {},
                initials: initials[1],
              ),
            ],
          ),
        ),
      );
      expect(find.text('T6'), findsOneWidget);
      expect(find.text('T7'), findsOneWidget);
      expect(find.text('T1'), findsNothing);
    });
  });

  group('FamilyMemberRow', () {
    testWidgets('shows the name and a line with age band and allergens', (
      tester,
    ) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: FamilyMemberRow(
            profile: _diner(allergens: {'gluten'}),
            onTap: () {},
          ),
        ),
      );

      expect(find.text('Liam'), findsOneWidget);
      // ageBandChild (sv) and the allergen label.
      expect(find.text('Barn · Gluten'), findsOneWidget);
    });

    testWidgets('a member without allergies reads as the age band alone', (
      tester,
    ) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: FamilyMemberRow(profile: _diner(), onTap: () {}),
        ),
      );

      expect(find.text('Barn'), findsOneWidget);
    });

    testWidgets('is tappable and carries the edit a11y label', (tester) async {
      var tapped = false;
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: FamilyMemberRow(
            profile: _diner(),
            onTap: () => tapped = true,
          ),
        ),
      );

      expect(
        find.bySemanticsLabel(RegExp('Redigera familjemedlem')),
        findsOneWidget,
      );
      await tester.tap(find.byType(FamilyMemberRow));
      expect(tapped, isTrue);
      handle.dispose();
    });

    testWidgets('a teen still reads as its age band', (tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: FamilyMemberRow(
            profile: _diner(band: DinerAgeBand.teen),
            onTap: () {},
          ),
        ),
      );
      expect(find.text('Tonåring'), findsOneWidget);
    });
  });

  group('FamilyAccountRow', () {
    HouseholdRosterMember account() =>
        HouseholdRosterMember.fromUser(userId: 'u', displayName: 'Malin');

    testWidgets('says admin when the member is an admin', (tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: FamilyAccountRow(member: account(), isAdmin: true),
        ),
      );
      expect(find.text('Malin'), findsOneWidget);
      expect(find.text('Admin'), findsOneWidget);
    });

    testWidgets('says Du on the signed-in user\'s own row', (tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: FamilyAccountRow(
            member: account(),
            isAdmin: true,
            isCurrentUser: true,
          ),
        ),
      );
      expect(find.text('Du · admin'), findsOneWidget);
    });

    testWidgets('shows the initials it is given rather than its own', (
      tester,
    ) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: FamilyAccountRow(
            member: account(),
            isAdmin: false,
            initials: 'Ma',
          ),
        ),
      );
      expect(find.text('Ma'), findsOneWidget);
      expect(find.text('M'), findsNothing);
    });

    testWidgets('a member who is neither you nor admin reads as Vuxen', (
      tester,
    ) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: FamilyAccountRow(member: account(), isAdmin: false),
        ),
      );
      expect(find.text('Vuxen'), findsOneWidget);
      expect(find.textContaining('admin'), findsNothing);
    });
  });

  group('FamilyAvatar', () {
    testWidgets('renders initials from the name', (tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: const FamilyAvatar(name: 'Emma', color: Colors.purple),
        ),
      );
      expect(find.text('E'), findsOneWidget);
    });
  });

  // BUT-2205: the row's own fill used to sit above the ink layer, so a
  // pressed row showed nothing.
  for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
    testWidgets('a pressed family member row shows surface.raised '
        '(${theme.brightness.name})', (tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Theme(
            data: theme,
            child: Material(
              child: FamilyMemberRow(profile: _diner(), onTap: () {}),
            ),
          ),
        ),
      );
      final row = find.text('Liam');
      expect(pressIsCovered(tester, row), isFalse);
      final gesture = await holdPress(tester, row);
      expect(
        paintsInkFill(tester, row, theme.colorScheme.surfaceContainerHighest),
        isTrue,
      );
      await gesture.cancel();
    });
  }
}
